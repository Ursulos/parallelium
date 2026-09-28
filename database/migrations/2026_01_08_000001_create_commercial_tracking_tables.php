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
