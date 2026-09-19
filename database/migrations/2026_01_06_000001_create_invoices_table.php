<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('invoices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            // Une facture est toujours générée DEPUIS une vente existante
            // (§18) : les montants (sous-total, remise, total, payé, reste)
            // ne sont jamais dupliqués ici, ils sont lus depuis la vente
            // liée — une information saisie une fois est réutilisée
            // partout (§64), jamais resaisie ni copiée.
            $table->foreignId('sale_id')->unique()->constrained()->cascadeOnDelete();
            $table->string('invoice_number');
            $table->string('status')->default('issued'); // draft | issued | partially_paid | paid | cancelled
            $table->timestamp('issued_at')->useCurrent();
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['company_id', 'invoice_number']);
        });

        // La colonne sales.invoice_id existe depuis la Phase 4 (nullable,
        // sans contrainte car la table invoices n'existait pas encore).
        // On ajoute la contrainte maintenant que c'est possible.
        Schema::table('sales', function (Blueprint $table) {
            $table->foreign('invoice_id')->references('id')->on('invoices')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('sales', function (Blueprint $table) {
            $table->dropForeign(['invoice_id']);
        });

        Schema::dropIfExists('invoices');
    }
};
