<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
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
