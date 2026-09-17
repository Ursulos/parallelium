<?php

namespace App\Support;

use App\Models\Company;
use Illuminate\Support\Facades\Auth;

/**
 * Point d'accès unique à l'entreprise (tenant) courante.
 *
 * Le tenant est TOUJOURS déterminé depuis l'utilisateur authentifié côté
 * serveur — jamais depuis un paramètre de route, un champ caché de
 * formulaire ou un header envoyé par le navigateur.
 */
class Tenant
{
    protected static ?Company $current = null;

    public static function check(): bool
    {
        return Auth::check() && Auth::user()->company_id !== null;
    }

    public static function id(): ?int
    {
        return Auth::user()?->company_id;
    }

    public static function current(): ?Company
    {
        if (! self::check()) {
            return null;
        }

        if (self::$current && self::$current->id === self::id()) {
            return self::$current;
        }

        return self::$current = Auth::user()->company;
    }

    /**
     * Utilisé uniquement juste après la création d'une entreprise
     * (avant que l'utilisateur ne soit rattaché), pour éviter un
     * aller-retour base de données inutile.
     */
    public static function setCurrent(Company $company): void
    {
        self::$current = $company;
    }
}
