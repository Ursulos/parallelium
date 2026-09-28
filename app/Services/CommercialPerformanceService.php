<?php

namespace App\Services;

use App\Enums\ObjectiveScope;
use App\Models\Commercial;
use App\Models\CommercialObjective;
use App\Models\CommercialSale;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * Calculs du module "Suivi commercial" (§9-12 du cahier des charges).
 * Point de passage UNIQUE pour tout calcul de réalisation/objectif/écart/
 * taux — jamais dupliqué à la main dans une vue ou un contrôleur.
 *
 * IMPORTANT : comme le reste de l'application, l'isolation multi-tenant
 * ici repose sur le scope Eloquent automatique (BelongsToCompany), qui
 * ne s'applique que dans un contexte HTTP authentifié (Tenant::check()).
 * Ce service ne doit donc être appelé que depuis un contrôleur derrière
 * le middleware 'auth', jamais depuis une commande console sans avoir
 * authentifié un utilisateur au préalable (voir la note similaire dans
 * ProductService et le bug corrigé dans app/Models/User.php).
 */
class CommercialPerformanceService
{
    /**
     * Réalisation (somme des quantités) sur une période, avec filtres
     * optionnels commercial_id / sector_id / city_id.
     */
    public function realization(Carbon $from, Carbon $to, array $filters = []): int
    {
        return (int) $this->baseQuery($from, $to, $filters)->sum('quantity');
    }

    public function realizationAmount(Carbon $from, Carbon $to, array $filters = []): float
    {
        return (float) $this->baseQuery($from, $to, $filters)->sum('amount');
    }

    protected function baseQuery(Carbon $from, Carbon $to, array $filters = [])
    {
        return CommercialSale::query()
            ->betweenDates($from, $to)
            ->when($filters['commercial_id'] ?? null, fn ($q, $v) => $q->where('commercial_id', $v))
            ->when($filters['sector_id'] ?? null, fn ($q, $v) => $q->where('sector_id', $v))
            ->when($filters['city_id'] ?? null, fn ($q, $v) => $q->where('city_id', $v));
    }

    /**
     * Objectif enregistré pour une portée précise (§7-8). Retourne null
     * si aucun objectif n'a été défini — jamais 0 par défaut, pour
     * distinguer "objectif de zéro" de "pas d'objectif" (§9).
     */
    public function objective(int $year, int $month, ObjectiveScope $scope, ?int $entityId = null): ?int
    {
        $query = CommercialObjective::forYearMonth($year, $month)->where('scope', $scope->value);

        $query = match ($scope) {
            ObjectiveScope::Commercial => $query->where('commercial_id', $entityId),
            ObjectiveScope::Sector => $query->where('sector_id', $entityId),
            ObjectiveScope::City => $query->where('city_id', $entityId),
            ObjectiveScope::Global => $query,
        };

        return $query->value('target_volume');
    }

    /**
     * Écart et taux d'atteinte (§9). Ne divise jamais par zéro : si aucun
     * objectif n'est défini, le taux reste null plutôt que de planter ou
     * d'afficher un chiffre trompeur.
     *
     * @return array{objectif: ?int, realisation: int, ecart: ?int, taux: ?float}
     */
    public function performance(int $realisation, ?int $objectif): array
    {
        return [
            'objectif' => $objectif,
            'realisation' => $realisation,
            'ecart' => is_null($objectif) ? null : $realisation - $objectif,
            'taux' => (is_null($objectif) || $objectif <= 0) ? null : round(($realisation / $objectif) * 100, 1),
        ];
    }

    /**
     * Suivi hebdomadaire (§6) : un commercial par ligne, une colonne par
     * jour ouvré (lundi à samedi par défaut — le dimanche est prévu dans
     * le schéma mais ignoré par défaut, comme demandé), total calculé
     * automatiquement.
     */
    public function weeklyBreakdown(Carbon $weekStart, Carbon $weekEnd, array $filters = [], bool $includeSunday = false): Collection
    {
        $commercials = $this->scopedCommercials($filters);

        $sales = $this->baseQuery($weekStart, $weekEnd, $filters)
            ->selectRaw('commercial_id, sale_date, SUM(quantity) as total')
            ->groupBy('commercial_id', 'sale_date')
            ->get()
            ->groupBy('commercial_id');

        $days = collect();
        for ($d = $weekStart->copy(); $d->lte($weekEnd); $d->addDay()) {
            if (! $includeSunday && $d->isSunday()) {
                continue;
            }
            $days->push($d->copy());
        }

        return $commercials->map(function (Commercial $commercial) use ($sales, $days) {
            $perDay = $sales->get($commercial->id, collect())->keyBy(fn ($row) => $row->sale_date->format('Y-m-d'));

            $values = $days->map(fn (Carbon $day) => (int) ($perDay->get($day->format('Y-m-d'))->total ?? 0));

            return [
                'commercial' => $commercial,
                'values' => $values,
                'total' => $values->sum(),
            ];
        });
    }

    /**
     * Suivi mensuel (§10) : objectif / réalisation / écart / taux par
     * commercial, plus le total équipe.
     */
    public function monthlyByCommercial(int $year, int $month, array $filters = []): array
    {
        $from = Carbon::create($year, $month, 1)->startOfMonth();
        $to = $from->copy()->endOfMonth();

        $commercials = $this->scopedCommercials($filters);

        $rows = $commercials->map(function (Commercial $commercial) use ($year, $month, $from, $to) {
            $realisation = $this->realization($from, $to, ['commercial_id' => $commercial->id]);
            $objectif = $this->objective($year, $month, ObjectiveScope::Commercial, $commercial->id);

            return array_merge(['commercial' => $commercial], $this->performance($realisation, $objectif));
        });

        $teamRealisation = (int) $rows->sum('realisation');
        $teamObjectif = $rows->every(fn ($r) => is_null($r['objectif'])) ? null : (int) $rows->sum('objectif');

        return [
            'rows' => $rows,
            'team' => $this->performance($teamRealisation, $teamObjectif),
        ];
    }

    /**
     * Analyse annuelle (§11-12) : les 12 mois côte à côte pour chaque
     * commercial, en mode réalisation, objectif, taux ou écart.
     */
    public function annualByCommercial(int $year, array $filters = [], string $mode = 'realisation'): array
    {
        $commercials = $this->scopedCommercials($filters);

        $rows = $commercials->map(function (Commercial $commercial) use ($year, $mode) {
            $months = collect(range(1, 12))->map(function (int $month) use ($year, $commercial, $mode) {
                $from = Carbon::create($year, $month, 1)->startOfMonth();
                $to = $from->copy()->endOfMonth();

                $realisation = $this->realization($from, $to, ['commercial_id' => $commercial->id]);
                $objectif = $this->objective($year, $month, ObjectiveScope::Commercial, $commercial->id);
                $perf = $this->performance($realisation, $objectif);

                return match ($mode) {
                    'objectif' => $objectif,
                    'taux' => $perf['taux'],
                    'ecart' => $perf['ecart'],
                    default => $realisation,
                };
            });

            return [
                'commercial' => $commercial,
                'months' => $months,
                'total' => $mode === 'taux' ? null : $months->filter(fn ($v) => ! is_null($v))->sum(),
            ];
        });

        $annualRealisation = (int) $this->realization(
            Carbon::create($year, 1, 1)->startOfYear(),
            Carbon::create($year, 12, 31)->endOfYear(),
            $filters
        );
        $annualObjectif = $this->annualGlobalObjective($year, $filters);

        return [
            'rows' => $rows,
            'summary' => $this->performance($annualRealisation, $annualObjectif),
        ];
    }

    protected function annualGlobalObjective(int $year, array $filters = []): ?int
    {
        $sum = null;

        for ($month = 1; $month <= 12; $month++) {
            $value = ! empty($filters['commercial_id'])
                ? $this->objective($year, $month, ObjectiveScope::Commercial, $filters['commercial_id'])
                : $this->objective($year, $month, ObjectiveScope::Global);

            if (! is_null($value)) {
                $sum = ($sum ?? 0) + $value;
            }
        }

        return $sum;
    }

    /**
     * Alerte de cohérence (§8) : compare un objectif global à la somme
     * des objectifs individuels du mois. N'empêche jamais la saisie —
     * juste une information.
     */
    public function objectiveConsistency(int $year, int $month): ?array
    {
        $global = $this->objective($year, $month, ObjectiveScope::Global);

        if (is_null($global)) {
            return null;
        }

        $individualSum = (int) CommercialObjective::forYearMonth($year, $month)
            ->where('scope', ObjectiveScope::Commercial->value)
            ->sum('target_volume');

        return [
            'global' => $global,
            'individual_sum' => $individualSum,
            'difference' => $global - $individualSum,
        ];
    }

    protected function scopedCommercials(array $filters = []): Collection
    {
        return Commercial::active()
            ->when($filters['commercial_id'] ?? null, fn ($q, $v) => $q->where('id', $v))
            ->when($filters['sector_id'] ?? null, fn ($q, $v) => $q->where('sector_id', $v))
            ->when($filters['city_id'] ?? null, fn ($q, $v) => $q->where('city_id', $v))
            ->orderBy('first_name')
            ->get();
    }
}
