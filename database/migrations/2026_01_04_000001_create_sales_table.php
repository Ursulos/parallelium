<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sales', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('customer_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();

            // Pas de contrainte FK vers invoices pour l'instant (module
            // Facturation prévu en Phase 6) : la colonne est prête, la
            // contrainte sera ajoutée quand la table existera.
            $table->unsignedBigInteger('invoice_id')->nullable();

            $table->string('sale_number')->nullable();

            // Tous les montants sont RECALCULÉS côté serveur (voir
            // SaleService) — jamais fait confiance à ce qu'envoie le
            // navigateur (cahier des charges §49).
            $table->decimal('subtotal', 14, 2)->default(0);
            $table->decimal('discount', 14, 2)->default(0);
            $table->decimal('tax_amount', 14, 2)->nullable();
            $table->decimal('total_amount', 14, 2)->default(0);
            $table->decimal('paid_amount', 14, 2)->default(0);
            $table->decimal('remaining_amount', 14, 2)->default(0);

            $table->string('payment_status')->default('unpaid'); // unpaid | partially_paid | paid
            $table->string('sale_status')->default('completed'); // completed | cancelled
            $table->string('payment_method');
            $table->text('notes')->nullable();
            $table->timestamp('sold_at')->useCurrent();
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['company_id', 'sale_number']);
            $table->index(['company_id', 'sale_status', 'sold_at']);
            $table->index(['company_id', 'payment_status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sales');
    }
};
