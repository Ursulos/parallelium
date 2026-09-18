<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Expense;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ExpenseTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([PermissionSeeder::class, RoleSeeder::class]);
        Storage::fake('public');
    }

    protected function ownerFor(Company $company): User
    {
        $role = Role::whereNull('company_id')->where('slug', 'owner')->first();

        return User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);
    }

    public function test_owner_can_create_an_expense_with_a_receipt(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);

        $receipt = UploadedFile::fake()->create('facture.pdf', 200, 'application/pdf');

        $response = $this->actingAs($owner)->post(route('expenses.store'), [
            'category' => 'transport',
            'amount' => 25000,
            'payment_method' => 'cash',
            'expense_date' => now()->format('Y-m-d'),
            'receipt' => $receipt,
        ]);

        $response->assertRedirect(route('expenses.index'));

        $expense = Expense::first();
        $this->assertNotNull($expense);
        $this->assertEquals(25000, $expense->amount);
        $this->assertNotNull($expense->receipt_path);
        Storage::disk('public')->assertExists($expense->receipt_path);
        // Le nom de fichier stocké ne doit jamais être le nom original envoyé.
        $this->assertStringNotContainsString('facture.pdf', $expense->receipt_path);
    }

    public function test_a_disallowed_file_type_is_rejected(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);

        $file = UploadedFile::fake()->create('script.exe', 10, 'application/x-msdownload');

        $this->actingAs($owner)->post(route('expenses.store'), [
            'category' => 'transport',
            'amount' => 1000,
            'payment_method' => 'cash',
            'expense_date' => now()->format('Y-m-d'),
            'receipt' => $file,
        ])->assertSessionHasErrors('receipt');

        $this->assertDatabaseCount('expenses', 0);
    }

    public function test_a_seller_cannot_view_expenses(): void
    {
        $company = Company::factory()->create();
        $sellerRole = Role::whereNull('company_id')->where('slug', 'seller')->first();
        $seller = User::factory()->create(['company_id' => $company->id, 'role_id' => $sellerRole->id]);

        $this->actingAs($seller)->get(route('expenses.index'))->assertForbidden();
    }

    public function test_a_company_cannot_see_another_companys_expenses(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();

        Expense::factory()->create(['company_id' => $companyA->id, 'amount' => 1000]);
        Expense::factory()->create(['company_id' => $companyB->id, 'amount' => 2000]);

        $ownerA = $this->ownerFor($companyA);
        $this->actingAs($ownerA);

        $this->assertEquals(1000, Expense::sum('amount'));
    }
}
