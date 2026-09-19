<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

/**
 * Administrateur PLATEFORME (l'éditeur de Parallelium), distinct des
 * utilisateurs d'entreprise (App\Models\User). Authentifié via le guard
 * "admin" (voir config/auth.php) — jamais mélangé avec le guard "web".
 */
class Admin extends Authenticatable
{
    use Notifiable;

    protected $fillable = ['name', 'email', 'password'];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }
}
