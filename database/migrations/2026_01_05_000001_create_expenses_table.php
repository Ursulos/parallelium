<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('expenses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('expense_number')->nullable();
            // Catégories fixes (§17 du cahier des charges) : pas de table
            // dédiée pour la V1, contrairement aux catégories produits qui,
            // elles, sont gérées par entreprise.
            $table->string('category');
            $table->string('supplier_name')->nullable();
            $table->decimal('amount', 14, 2);
            $table->string('payment_method');
            $table->text('description')->nullable();
            // Chemin de stockage interne (nom de fichier sécurisé, généré
            // par Laravel) — jamais le nom original envoyé par l'utilisateur.
            $table->string('receipt_path')->nullable();
            $table->date('expense_date');
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['company_id', 'expense_number']);
            $table->index(['company_id', 'category']);
            $table->index(['company_id', 'expense_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('expenses');
    }
};
