#!/usr/bin/env bash
#
# Parallelium - Module Suivi commercial (fondations : migrations, modeles,
# permissions, service de calcul, donnees de demo, tests).
# Les pages (hebdo/mensuel/annuel/dashboard/CRUD) arrivent dans un prochain
# script - ceci ne cree encore AUCUNE route ni vue.
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
set -e
echo "Application des fichiers..."

mkdir -p "database/migrations"
cat > "database/migrations/2026_01_08_000001_create_commercial_tracking_tables.php" << 'PARALLELIUM_FILE_EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Module "Suivi commercial" — indépendant du module Ventes/Stock existant
 * (§23 : Stock répond à "combien de produits ?", ce module répond à
 * "combien vendu vs objectif ?"). Aucune migration existante n'est
 * modifiée ; aucune table existante n'est touchée.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sales_sectors', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['company_id', 'name']);
        });

        Schema::create('sales_cities', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['company_id', 'name']);
        });

        Schema::create('commercials', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            // Compte Parallelium éventuel du commercial (pour qu'il puisse
            // se connecter et voir ses propres performances — §2). Nullable
            // car un commercial "terrain" n'a pas forcément de connexion.
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            // Responsable / manager (§3) — un utilisateur existant.
            $table->foreignId('manager_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('sector_id')->nullable()->constrained('sales_sectors')->nullOnDelete();
            $table->foreignId('city_id')->nullable()->constrained('sales_cities')->nullOnDelete();
            $table->string('first_name');
            $table->string('last_name')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            // Jamais de suppression définitive : un commercial inactif garde
            // tout son historique de ventes et de performances (§20).
            $table->softDeletes();

            $table->index(['company_id', 'is_active']);
        });

        Schema::create('commercial_sales', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('commercial_id')->constrained()->cascadeOnDelete();
            // Réutilise le modèle Customer existant (Phase 3) — jamais de
            // doublon de structure client (voir extension §2).
            $table->foreignId('customer_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('sector_id')->nullable()->constrained('sales_sectors')->nullOnDelete();
            $table->foreignId('city_id')->nullable()->constrained('sales_cities')->nullOnDelete();
            $table->date('sale_date');
            $table->unsignedInteger('quantity');
            // Montant optionnel : le suivi de volume est la priorité (§5),
            // le CA reste disponible sans complexifier la V1.
            $table->decimal('amount', 14, 2)->nullable();
            // Commande exceptionnelle (extension §4) : jamais détectée comme
            // une vérité automatique, seulement une aide — confirmée ou non
            // par le Manager.
            $table->boolean('is_exceptional')->default(false);
            $table->text('comment')->nullable();
            $table->foreignId('entered_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['company_id', 'commercial_id', 'sale_date']);
            $table->index(['company_id', 'sale_date']);
        });

        Schema::create('commercial_objectives', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->unsignedSmallInteger('year');
            $table->unsignedTinyInteger('month');
            // Portée de l'objectif (§7-8) : un seul des 3 champs ci-dessous
            // est renseigné selon 'scope', jamais plusieurs à la fois — un
            // objectif "global" n'a ni commercial_id, ni sector_id, ni city_id.
            $table->string('scope'); // commercial | sector | city | global
            $table->foreignId('commercial_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('sector_id')->nullable()->constrained('sales_sectors')->cascadeOnDelete();
            $table->foreignId('city_id')->nullable()->constrained('sales_cities')->cascadeOnDelete();
            $table->unsignedInteger('target_volume');
            $table->decimal('target_amount', 14, 2)->nullable();
            $table->timestamps();

            $table->index(['company_id', 'year', 'month', 'scope']);
            $table->unique(
                ['company_id', 'year', 'month', 'scope', 'commercial_id', 'sector_id', 'city_id'],
                'commercial_objectives_unique_scope'
            );
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('commercial_objectives');
        Schema::dropIfExists('commercial_sales');
        Schema::dropIfExists('commercials');
        Schema::dropIfExists('sales_cities');
        Schema::dropIfExists('sales_sectors');
    }
};
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/SalesSector.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class SalesSector extends Model
{
    use BelongsToCompany, SoftDeletes;

    protected $table = 'sales_sectors';

    protected $fillable = ['company_id', 'name', 'is_active'];

    protected function casts(): array
    {
        return ['is_active' => 'boolean'];
    }

    public function commercials(): HasMany
    {
        return $this->hasMany(Commercial::class, 'sector_id');
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/SalesCity.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class SalesCity extends Model
{
    use BelongsToCompany, SoftDeletes;

    protected $table = 'sales_cities';

    protected $fillable = ['company_id', 'name', 'is_active'];

    protected function casts(): array
    {
        return ['is_active' => 'boolean'];
    }

    public function commercials(): HasMany
    {
        return $this->hasMany(Commercial::class, 'city_id');
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/Commercial.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Commercial extends Model
{
    use BelongsToCompany, SoftDeletes;

    protected $fillable = [
        'company_id', 'user_id', 'manager_id', 'sector_id', 'city_id',
        'first_name', 'last_name', 'is_active',
    ];

    protected function casts(): array
    {
        return ['is_active' => 'boolean'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function manager(): BelongsTo
    {
        return $this->belongsTo(User::class, 'manager_id');
    }

    public function sector(): BelongsTo
    {
        return $this->belongsTo(SalesSector::class, 'sector_id');
    }

    public function city(): BelongsTo
    {
        return $this->belongsTo(SalesCity::class, 'city_id');
    }

    public function sales(): HasMany
    {
        return $this->hasMany(CommercialSale::class);
    }

    public function objectives(): HasMany
    {
        return $this->hasMany(CommercialObjective::class);
    }

    public function fullName(): string
    {
        return trim("{$this->first_name} {$this->last_name}");
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/CommercialSale.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class CommercialSale extends Model
{
    use BelongsToCompany, SoftDeletes;

    protected $fillable = [
        'company_id', 'commercial_id', 'customer_id', 'sector_id', 'city_id',
        'sale_date', 'quantity', 'amount', 'is_exceptional', 'comment', 'entered_by',
    ];

    protected function casts(): array
    {
        return [
            'sale_date' => 'date',
            'amount' => 'decimal:2',
            'is_exceptional' => 'boolean',
        ];
    }

    public function commercial(): BelongsTo
    {
        return $this->belongsTo(Commercial::class);
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function sector(): BelongsTo
    {
        return $this->belongsTo(SalesSector::class, 'sector_id');
    }

    public function city(): BelongsTo
    {
        return $this->belongsTo(SalesCity::class, 'city_id');
    }

    public function enteredBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'entered_by');
    }

    public function scopeBetweenDates(Builder $query, $from, $to): Builder
    {
        return $query->whereBetween('sale_date', [$from, $to]);
    }

    public function scopeForYearMonth(Builder $query, int $year, int $month): Builder
    {
        return $query->whereYear('sale_date', $year)->whereMonth('sale_date', $month);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Enums"
cat > "app/Enums/ObjectiveScope.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Enums;

enum ObjectiveScope: string
{
    case Commercial = 'commercial';
    case Sector = 'sector';
    case City = 'city';
    case Global = 'global';

    public function label(): string
    {
        return match ($this) {
            self::Commercial => 'Par commercial',
            self::Sector => 'Par secteur',
            self::City => 'Par ville',
            self::Global => 'Global entreprise',
        };
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/CommercialObjective.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Enums\ObjectiveScope;
use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CommercialObjective extends Model
{
    use BelongsToCompany;

    protected $fillable = [
        'company_id', 'year', 'month', 'scope', 'commercial_id', 'sector_id', 'city_id',
        'target_volume', 'target_amount',
    ];

    protected function casts(): array
    {
        return [
            'scope' => ObjectiveScope::class,
            'target_amount' => 'decimal:2',
        ];
    }

    public function commercial(): BelongsTo
    {
        return $this->belongsTo(Commercial::class);
    }

    public function sector(): BelongsTo
    {
        return $this->belongsTo(SalesSector::class, 'sector_id');
    }

    public function city(): BelongsTo
    {
        return $this->belongsTo(SalesCity::class, 'city_id');
    }

    public function scopeForYearMonth(Builder $query, int $year, int $month): Builder
    {
        return $query->where('year', $year)->where('month', $month);
    }

    public function scopeGlobal(Builder $query): Builder
    {
        return $query->where('scope', ObjectiveScope::Global->value);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/Customer.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Customer extends Model
{
    use BelongsToCompany, HasFactory, SoftDeletes;

    protected $fillable = [
        'company_id', 'name', 'phone', 'email', 'address', 'notes', 'credit_limit', 'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'credit_limit' => 'decimal:2',
        ];
    }

    public function sales(): HasMany
    {
        return $this->hasMany(Sale::class);
    }

    /**
     * Ventes du module "Suivi commercial" — distinct des ventes du module
     * Ventes/Stock (voir §23 du cahier des charges de ce module).
     */
    public function commercialSales(): HasMany
    {
        return $this->hasMany(CommercialSale::class);
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }

    public function scopeSearch(Builder $query, ?string $term): Builder
    {
        if (! $term) {
            return $query;
        }

        return $query->where(function (Builder $q) use ($term) {
            $q->where('name', 'like', "%{$term}%")
                ->orWhere('phone', 'like', "%{$term}%")
                ->orWhere('email', 'like', "%{$term}%");
        });
    }

    public function totalPurchases(): float
    {
        return (float) $this->sales()->completed()->sum('total_amount');
    }

    public function totalPaid(): float
    {
        return (float) $this->sales()->completed()->sum('paid_amount');
    }

    public function totalRemaining(): float
    {
        return (float) $this->sales()->completed()->sum('remaining_amount');
    }

    public function lastOrderAt(): ?\Illuminate\Support\Carbon
    {
        return $this->sales()->completed()->latest('sold_at')->value('sold_at');
    }

    // Les factures (Phase 6) s'ajouteront ici de la même façon.
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/User.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    // IMPORTANT : ne JAMAIS ajouter le trait BelongsToCompany ici.
    // Le guard d'authentification résout l'utilisateur courant via
    // Auth::user(), qui interroge ce modèle. Or BelongsToCompany
    // détermine l'entreprise courante via Tenant::check(), qui appelle
    // lui-même Auth::user() — cela crée une récursion infinie dès la
    // connexion (500 systématique après login). L'isolation tenant sur
    // User se fait donc à la main : ->where('company_id', Tenant::id())
    // explicitement partout où c'est nécessaire (voir EmployeeController).
    use HasFactory, Notifiable, SoftDeletes;

    protected $fillable = [
        'company_id',
        'role_id',
        'name',
        'email',
        'phone',
        'avatar',
        'password',
        'is_active',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'last_login_at' => 'datetime',
            'password' => 'hashed',
            'is_active' => 'boolean',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class);
    }

    /**
     * Fiche "commercial" éventuellement associée à ce compte (module
     * Suivi commercial) — permet à un Vendeur connecté de retrouver ses
     * propres performances (§2 : jamais celles des autres équipes).
     */
    public function commercialProfile(): HasOne
    {
        return $this->hasOne(Commercial::class, 'user_id');
    }

    /**
     * Vérifie si l'utilisateur possède une permission donnée, via son rôle.
     * Source de vérité utilisée par les Gates (voir AuthServiceProvider).
     */
    public function hasPermission(string $slug): bool
    {
        if (! $this->role) {
            return false;
        }

        return $this->role->permissions()
            ->where('slug', $slug)
            ->exists();
    }

    public function isOwner(): bool
    {
        return $this->role?->slug === 'owner';
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Services"
cat > "app/Services/CommercialPerformanceService.php" << 'PARALLELIUM_FILE_EOF'
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
PARALLELIUM_FILE_EOF

mkdir -p "database/seeders"
cat > "database/seeders/PermissionSeeder.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Seeders;

use App\Models\Permission;
use Illuminate\Database\Seeder;

class PermissionSeeder extends Seeder
{
    public function run(): void
    {
        $groups = [
            'dashboard' => ['view', 'revenue'],
            'products' => ['view', 'create', 'update', 'delete'],
            'stock' => ['view', 'manage'],
            'customers' => ['view', 'create', 'update', 'delete'],
            'sales' => ['view', 'create', 'cancel'],
            'expenses' => ['view', 'create', 'update', 'delete'],
            'invoices' => ['view', 'create'],
            'reports' => ['view'],
            'employees' => ['view', 'manage'],
            'settings' => ['manage'],
            // Module "Suivi commercial" : view = toute l'équipe (Owner/
            // Manager) ; view_own = seulement ses propres performances
            // (Vendeur/Commercial) ; manage = commerciaux/secteurs/villes/
            // objectifs ; enter_sales = saisir des ventes commerciales.
            'commercial' => ['view', 'view_own', 'manage', 'enter_sales'],
        ];

        foreach ($groups as $group => $actions) {
            foreach ($actions as $action) {
                Permission::updateOrCreate(
                    ['slug' => "{$group}.{$action}"],
                    ['name' => ucfirst($group)." — ".ucfirst($action), 'group' => $group]
                );
            }
        }
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/seeders"
cat > "database/seeders/RoleSeeder.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Seeders;

use App\Models\Permission;
use App\Models\Role;
use Illuminate\Database\Seeder;

/**
 * Rôles "système" (company_id = null), partagés par toutes les entreprises.
 * Voir §23 du cahier des charges pour le détail des accès par rôle.
 */
class RoleSeeder extends Seeder
{
    public function run(): void
    {
        $all = Permission::pluck('slug');

        $owner = Role::updateOrCreate(
            ['company_id' => null, 'slug' => 'owner'],
            ['name' => 'Propriétaire', 'is_system' => true]
        );
        $owner->permissions()->sync(Permission::pluck('id'));

        $manager = Role::updateOrCreate(
            ['company_id' => null, 'slug' => 'manager'],
            ['name' => 'Manager', 'is_system' => true]
        );
        $manager->permissions()->sync(
            Permission::where('slug', '!=', 'settings.manage')
                ->where('slug', '!=', 'employees.manage')
                ->pluck('id')
        );

        $seller = Role::updateOrCreate(
            ['company_id' => null, 'slug' => 'seller'],
            ['name' => 'Vendeur', 'is_system' => true]
        );
        $seller->permissions()->sync(
            Permission::whereIn('slug', [
                'dashboard.view',
                'products.view',
                'customers.view',
                'customers.create',
                'customers.update',
                'sales.view',
                'sales.create',
                'commercial.view_own',
                'commercial.enter_sales',
            ])->pluck('id')
        );

        $accountant = Role::updateOrCreate(
            ['company_id' => null, 'slug' => 'accountant'],
            ['name' => 'Comptable', 'is_system' => true]
        );
        $accountant->permissions()->sync(
            Permission::whereIn('slug', [
                'dashboard.view',
                'reports.view',
                'expenses.view',
                'invoices.view',
                'sales.view',
            ])->pluck('id')
        );
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/seeders"
cat > "database/seeders/CommercialTrackingDemoSeeder.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Seeders;

use App\Enums\ObjectiveScope;
use App\Models\Commercial;
use App\Models\CommercialObjective;
use App\Models\CommercialSale;
use App\Models\Company;
use App\Models\SalesCity;
use App\Models\SalesSector;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;

/**
 * Jeu de données réaliste pour le module "Suivi commercial" (§25 du
 * cahier des charges du module) : 3 commerciaux, 3 villes, 2 secteurs,
 * plusieurs mois de ventes et d'objectifs, pour que les calculs
 * (écart, taux d'atteinte, comparaison annuelle) soient visibles
 * immédiatement après installation.
 */
class CommercialTrackingDemoSeeder extends Seeder
{
    public function run(): void
    {
        $company = Company::where('name', 'Parallelium Demo')->first();

        if (! $company || SalesSector::withoutTenantScope()->where('company_id', $company->id)->exists()) {
            return;
        }

        $sectors = collect(['Centre', 'Nord'])->mapWithKeys(
            fn ($name) => [$name => SalesSector::create(['company_id' => $company->id, 'name' => $name, 'is_active' => true])->id]
        );

        $cities = collect(['Antananarivo', 'Toamasina', 'Antsirabe'])->mapWithKeys(
            fn ($name) => [$name => SalesCity::create(['company_id' => $company->id, 'name' => $name, 'is_active' => true])->id]
        );

        $sellerUser = User::where('company_id', $company->id)->where('email', 'seller@parallelium.demo')->first();
        $ownerUser = User::where('company_id', $company->id)->where('email', 'owner@parallelium.demo')->first();

        $commercials = [
            'CHAMINA' => Commercial::create([
                'company_id' => $company->id,
                'user_id' => $sellerUser?->id,
                'manager_id' => $ownerUser?->id,
                'first_name' => 'CHAMINA',
                'sector_id' => $sectors['Centre'],
                'city_id' => $cities['Antananarivo'],
                'is_active' => true,
            ]),
            'SAIDY' => Commercial::create([
                'company_id' => $company->id,
                'manager_id' => $ownerUser?->id,
                'first_name' => 'SAIDY',
                'sector_id' => $sectors['Centre'],
                'city_id' => $cities['Toamasina'],
                'is_active' => true,
            ]),
            'PONEY' => Commercial::create([
                'company_id' => $company->id,
                'manager_id' => $ownerUser?->id,
                'first_name' => 'PONEY',
                'sector_id' => $sectors['Nord'],
                'city_id' => $cities['Antsirabe'],
                'is_active' => true,
            ]),
        ];

        // Objectifs et réalisations sur les 3 derniers mois (dont le
        // mois courant), avec des volumes cohérents avec l'exemple du
        // cahier des charges (CHAMINA : objectif 725, réalisation 577).
        $monthlyTargets = [
            'CHAMINA' => 725,
            'SAIDY' => 450,
            'PONEY' => 600,
        ];
        $monthlyRealisationRatio = [
            'CHAMINA' => 0.796, // 79,6 % -> ~577
            'SAIDY' => 1.004,   // 100,4 % -> ~452
            'PONEY' => 1.075,   // 107,5 % -> ~645
        ];

        for ($monthsAgo = 2; $monthsAgo >= 0; $monthsAgo--) {
            $period = now()->subMonthsNoOverflow($monthsAgo);
            $year = (int) $period->format('Y');
            $month = (int) $period->format('n');

            $globalTarget = array_sum($monthlyTargets);
            CommercialObjective::create([
                'company_id' => $company->id,
                'year' => $year,
                'month' => $month,
                'scope' => ObjectiveScope::Global->value,
                'target_volume' => $globalTarget,
            ]);

            foreach ($commercials as $name => $commercial) {
                CommercialObjective::create([
                    'company_id' => $company->id,
                    'year' => $year,
                    'month' => $month,
                    'scope' => ObjectiveScope::Commercial->value,
                    'commercial_id' => $commercial->id,
                    'target_volume' => $monthlyTargets[$name],
                ]);

                $target = (int) round($monthlyTargets[$name] * $monthlyRealisationRatio[$name]);
                $this->spreadSalesAcrossMonth($company->id, $commercial, $year, $month, $target);
            }
        }
    }

    /**
     * Répartit un volume mensuel sur des jours ouvrés réalistes (jamais
     * une seule grosse ligne artificielle) pour que le suivi hebdomadaire
     * ait aussi des données à montrer.
     */
    protected function spreadSalesAcrossMonth(int $companyId, Commercial $commercial, int $year, int $month, int $totalVolume): void
    {
        $start = Carbon::create($year, $month, 1)->startOfMonth();
        $end = $start->copy()->endOfMonth();
        $workDays = collect();

        for ($d = $start->copy(); $d->lte($end); $d->addDay()) {
            if (! $d->isSunday()) {
                $workDays->push($d->copy());
            }
        }

        if ($workDays->isEmpty() || $totalVolume <= 0) {
            return;
        }

        $remaining = $totalVolume;
        $perDayBase = intdiv($totalVolume, $workDays->count());

        foreach ($workDays as $index => $day) {
            $isLast = $index === $workDays->count() - 1;
            $qty = $isLast ? $remaining : max(1, $perDayBase + rand(-2, 3));
            $qty = min($qty, $remaining);

            if ($qty <= 0) {
                continue;
            }

            CommercialSale::create([
                'company_id' => $companyId,
                'commercial_id' => $commercial->id,
                'sector_id' => $commercial->sector_id,
                'city_id' => $commercial->city_id,
                'sale_date' => $day->format('Y-m-d'),
                'quantity' => $qty,
                'entered_by' => $commercial->manager_id,
            ]);

            $remaining -= $qty;

            if ($remaining <= 0) {
                break;
            }
        }
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/seeders"
cat > "database/seeders/DatabaseSeeder.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            PermissionSeeder::class,
            RoleSeeder::class,
            DemoCompanySeeder::class,
            CommercialTrackingDemoSeeder::class,
            AdminSeeder::class,
        ]);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/factories"
cat > "database/factories/SalesSectorFactory.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Factories;

use App\Models\SalesSector;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<SalesSector> */
class SalesSectorFactory extends Factory
{
    protected $model = SalesSector::class;

    public function definition(): array
    {
        return ['name' => fake()->unique()->word(), 'is_active' => true];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/factories"
cat > "database/factories/SalesCityFactory.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Factories;

use App\Models\SalesCity;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<SalesCity> */
class SalesCityFactory extends Factory
{
    protected $model = SalesCity::class;

    public function definition(): array
    {
        return ['name' => fake()->unique()->city(), 'is_active' => true];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/factories"
cat > "database/factories/CommercialFactory.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Factories;

use App\Models\Commercial;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Commercial> */
class CommercialFactory extends Factory
{
    protected $model = Commercial::class;

    public function definition(): array
    {
        return [
            'first_name' => strtoupper(fake()->unique()->lastName()),
            'is_active' => true,
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "tests/Feature/Commercial"
cat > "tests/Feature/Commercial/CommercialPerformanceTest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Tests\Feature\Commercial;

use App\Enums\ObjectiveScope;
use App\Models\Commercial;
use App\Models\CommercialObjective;
use App\Models\CommercialSale;
use App\Models\Company;
use App\Models\Role;
use App\Models\SalesCity;
use App\Models\SalesSector;
use App\Models\User;
use App\Services\CommercialPerformanceService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

/**
 * Vérifie en priorité l'EXACTITUDE des calculs (§25 du cahier des
 * charges du module Suivi commercial) : écart, taux d'atteinte,
 * agrégations hebdo/mensuelle/annuelle, division par zéro, filtres,
 * historique conservé pour un commercial inactif.
 */
class CommercialPerformanceTest extends TestCase
{
    use RefreshDatabase;

    protected function ownerFor(Company $company): User
    {
        $role = Role::firstOrCreate(
            ['company_id' => null, 'slug' => 'owner'],
            ['name' => 'Propriétaire', 'is_system' => true]
        );

        return User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);
    }

    protected function makeCommercial(Company $company, string $name, ?SalesSector $sector = null, ?SalesCity $city = null): Commercial
    {
        return Commercial::create([
            'company_id' => $company->id,
            'first_name' => $name,
            'sector_id' => $sector?->id,
            'city_id' => $city?->id,
            'is_active' => true,
        ]);
    }

    protected function addSale(Company $company, Commercial $commercial, string $date, int $qty): void
    {
        CommercialSale::create([
            'company_id' => $company->id,
            'commercial_id' => $commercial->id,
            'sector_id' => $commercial->sector_id,
            'city_id' => $commercial->city_id,
            'sale_date' => $date,
            'quantity' => $qty,
        ]);
    }

    public function test_performance_computes_ecart_and_taux_correctly(): void
    {
        $service = new CommercialPerformanceService();

        // Exemple exact du cahier des charges : 577 / 725 = 79,59 % -> 79,6 %.
        $result = $service->performance(577, 725);

        $this->assertEquals(-148, $result['ecart']);
        $this->assertEquals(79.6, $result['taux']);
    }

    public function test_performance_never_divides_by_zero_when_no_objective_is_set(): void
    {
        $service = new CommercialPerformanceService();

        $result = $service->performance(300, null);

        $this->assertNull($result['ecart']);
        $this->assertNull($result['taux']);
        $this->assertEquals(300, $result['realisation']);
    }

    public function test_performance_never_divides_by_zero_when_objective_is_zero(): void
    {
        $service = new CommercialPerformanceService();

        $result = $service->performance(50, 0);

        $this->assertNull($result['taux']);
    }

    public function test_weekly_breakdown_sums_per_day_and_computes_total(): void
    {
        $company = Company::factory()->create();
        $this->actingAs($this->ownerFor($company));
        $commercial = $this->makeCommercial($company, 'CHAMINA');

        $monday = Carbon::parse('2026-03-02'); // un lundi
        $this->addSale($company, $commercial, $monday->format('Y-m-d'), 20);
        $this->addSale($company, $commercial, $monday->copy()->addDay()->format('Y-m-d'), 15);
        // Dimanche ignoré par défaut.
        $this->addSale($company, $commercial, $monday->copy()->addDays(6)->format('Y-m-d'), 999);

        $service = new CommercialPerformanceService();
        $breakdown = $service->weeklyBreakdown($monday, $monday->copy()->addDays(6));

        $row = $breakdown->firstWhere('commercial.id', $commercial->id);

        $this->assertEquals(35, $row['total']); // 20 + 15, sans le dimanche
    }

    public function test_monthly_report_computes_team_total_and_per_commercial_rates(): void
    {
        $company = Company::factory()->create();
        $this->actingAs($this->ownerFor($company));
        $chamina = $this->makeCommercial($company, 'CHAMINA');
        $saidy = $this->makeCommercial($company, 'SAIDY');

        $year = 2026;
        $month = 1;

        CommercialObjective::create(['company_id' => $company->id, 'year' => $year, 'month' => $month, 'scope' => ObjectiveScope::Commercial->value, 'commercial_id' => $chamina->id, 'target_volume' => 725]);
        CommercialObjective::create(['company_id' => $company->id, 'year' => $year, 'month' => $month, 'scope' => ObjectiveScope::Commercial->value, 'commercial_id' => $saidy->id, 'target_volume' => 450]);

        $this->addSale($company, $chamina, "{$year}-01-05", 577);
        $this->addSale($company, $saidy, "{$year}-01-05", 452);

        $service = new CommercialPerformanceService();
        $report = $service->monthlyByCommercial($year, $month);

        $chaminaRow = $report['rows']->firstWhere('commercial.id', $chamina->id);
        $this->assertEquals(-148, $chaminaRow['ecart']);
        $this->assertEquals(79.6, $chaminaRow['taux']);

        $this->assertEquals(1175, $report['team']['objectif']); // 725 + 450
        $this->assertEquals(1029, $report['team']['realisation']); // 577 + 452
        $this->assertEquals(-146, $report['team']['ecart']);
    }

    public function test_annual_report_lines_up_all_twelve_months(): void
    {
        $company = Company::factory()->create();
        $this->actingAs($this->ownerFor($company));
        $commercial = $this->makeCommercial($company, 'CHAMINA');

        $this->addSale($company, $commercial, '2026-01-10', 100);
        $this->addSale($company, $commercial, '2026-04-10', 250);

        $service = new CommercialPerformanceService();
        $report = $service->annualByCommercial(2026);

        $row = $report['rows']->firstWhere('commercial.id', $commercial->id);

        $this->assertCount(12, $row['months']);
        $this->assertEquals(100, $row['months'][0]); // Janvier (index 0)
        $this->assertEquals(0, $row['months'][1]);   // Février : aucune vente
        $this->assertEquals(250, $row['months'][3]); // Avril (index 3)
        $this->assertEquals(350, $row['total']);
    }

    public function test_filters_by_sector_and_city_restrict_the_results(): void
    {
        $company = Company::factory()->create();
        $this->actingAs($this->ownerFor($company));
        $sectorCentre = SalesSector::factory()->create(['company_id' => $company->id, 'name' => 'Centre']);
        $sectorNord = SalesSector::factory()->create(['company_id' => $company->id, 'name' => 'Nord']);
        $cityTana = SalesCity::factory()->create(['company_id' => $company->id, 'name' => 'Antananarivo']);

        $chamina = $this->makeCommercial($company, 'CHAMINA', $sectorCentre, $cityTana);
        $poney = $this->makeCommercial($company, 'PONEY', $sectorNord);

        $this->addSale($company, $chamina, '2026-02-10', 100);
        $this->addSale($company, $poney, '2026-02-10', 300);

        $service = new CommercialPerformanceService();

        $centreOnly = $service->realization(Carbon::parse('2026-02-01'), Carbon::parse('2026-02-28'), ['sector_id' => $sectorCentre->id]);
        $this->assertEquals(100, $centreOnly);

        $tanaOnly = $service->realization(Carbon::parse('2026-02-01'), Carbon::parse('2026-02-28'), ['city_id' => $cityTana->id]);
        $this->assertEquals(100, $tanaOnly);
    }

    public function test_an_inactive_commercials_sales_history_remains_intact(): void
    {
        $company = Company::factory()->create();
        $this->actingAs($this->ownerFor($company));
        $commercial = $this->makeCommercial($company, 'CHAMINA');
        $this->addSale($company, $commercial, '2026-01-15', 400);

        $commercial->update(['is_active' => false]);
        $commercial->delete(); // soft delete, comme un employé qui quitte l'entreprise

        $service = new CommercialPerformanceService();
        $realisation = $service->realization(Carbon::parse('2026-01-01'), Carbon::parse('2026-01-31'), ['commercial_id' => $commercial->id]);

        $this->assertEquals(400, $realisation);
        $this->assertSoftDeleted($commercial);
    }

    public function test_objective_consistency_reports_the_gap_without_blocking_anything(): void
    {
        $company = Company::factory()->create();
        $this->actingAs($this->ownerFor($company));
        $a = $this->makeCommercial($company, 'A');
        $b = $this->makeCommercial($company, 'B');
        $c = $this->makeCommercial($company, 'C');

        CommercialObjective::create(['company_id' => $company->id, 'year' => 2026, 'month' => 1, 'scope' => ObjectiveScope::Global->value, 'target_volume' => 10000]);
        CommercialObjective::create(['company_id' => $company->id, 'year' => 2026, 'month' => 1, 'scope' => ObjectiveScope::Commercial->value, 'commercial_id' => $a->id, 'target_volume' => 3000]);
        CommercialObjective::create(['company_id' => $company->id, 'year' => 2026, 'month' => 1, 'scope' => ObjectiveScope::Commercial->value, 'commercial_id' => $b->id, 'target_volume' => 2500]);
        CommercialObjective::create(['company_id' => $company->id, 'year' => 2026, 'month' => 1, 'scope' => ObjectiveScope::Commercial->value, 'commercial_id' => $c->id, 'target_volume' => 2000]);

        $service = new CommercialPerformanceService();
        $consistency = $service->objectiveConsistency(2026, 1);

        $this->assertEquals(10000, $consistency['global']);
        $this->assertEquals(7500, $consistency['individual_sum']);
        $this->assertEquals(2500, $consistency['difference']);
    }

    public function test_no_objective_defined_returns_null_consistency(): void
    {
        $company = Company::factory()->create();
        $this->actingAs($this->ownerFor($company));

        $service = new CommercialPerformanceService();
        $this->assertNull($service->objectiveConsistency(2026, 6));
    }

    public function test_a_companys_commercial_data_never_leaks_to_another_company(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();

        $this->actingAs($this->ownerFor($companyB));
        $commercialB = $this->makeCommercial($companyB, 'COMMERCIAL B');
        $this->addSale($companyB, $commercialB, '2026-03-10', 999);

        $this->actingAs($this->ownerFor($companyA));
        $commercialA = $this->makeCommercial($companyA, 'COMMERCIAL A');
        $this->addSale($companyA, $commercialA, '2026-03-10', 50);

        $service = new CommercialPerformanceService();
        $realisation = $service->realization(Carbon::parse('2026-03-01'), Carbon::parse('2026-03-31'));

        // Authentifié sur l'entreprise A : seule sa propre donnée doit
        // apparaître, jamais les 999 unités de l'entreprise B.
        $this->assertEquals(50, $realisation);
    }
}
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant :"
echo "  php artisan migrate"
echo "  php artisan db:seed --class=Database\\Seeders\\PermissionSeeder"
echo "  php artisan db:seed --class=Database\\Seeders\\RoleSeeder"
echo "  php artisan db:seed --class=Database\\Seeders\\CommercialTrackingDemoSeeder"
