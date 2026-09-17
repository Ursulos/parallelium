<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Model;

class Subscription extends Model
{
    use BelongsToCompany;

    protected $fillable = [
        'company_id', 'plan', 'status', 'trial_ends_at', 'current_period_ends_at',
    ];

    protected function casts(): array
    {
        return [
            'trial_ends_at' => 'datetime',
            'current_period_ends_at' => 'datetime',
        ];
    }

    public function planConfig(): array
    {
        return config("parallelium.plans.{$this->plan}", config('parallelium.plans.free'));
    }

    public function limit(string $key): ?int
    {
        return $this->planConfig()['limits'][$key] ?? null;
    }

    public function hasFeature(string $feature): bool
    {
        return in_array($feature, $this->planConfig()['features'] ?? [], true);
    }

    public function isOnTrial(): bool
    {
        return $this->status === 'trialing' && $this->trial_ends_at?->isFuture();
    }
}
