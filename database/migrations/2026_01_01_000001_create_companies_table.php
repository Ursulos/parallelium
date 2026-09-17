<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('companies', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('legal_name')->nullable();
            $table->string('logo')->nullable();
            $table->string('email')->nullable();
            $table->string('phone')->nullable();
            $table->string('address')->nullable();
            $table->string('city')->nullable();
            $table->string('country')->default('Madagascar');
            $table->string('currency', 3)->default(config('parallelium.default_currency', 'MGA'));
            $table->string('timezone')->default(config('parallelium.default_timezone', 'Indian/Antananarivo'));
            $table->string('business_type')->nullable();
            $table->string('tax_identifier')->nullable();

            // Numérotation des documents (personnalisable par entreprise).
            $table->string('invoice_prefix')->default(config('parallelium.document_prefixes.invoice', 'PAR'));
            $table->unsignedInteger('next_invoice_number')->default(1);
            $table->unsignedInteger('next_sale_number')->default(1);
            $table->unsignedInteger('next_expense_number')->default(1);

            // Onboarding.
            $table->boolean('onboarding_completed')->default(false);

            $table->enum('status', ['active', 'suspended', 'closed'])->default('active');
            $table->timestamps();
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('companies');
    }
};
