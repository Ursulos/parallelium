#!/usr/bin/env bash
#
# Parallelium - Phase 2 (Categories, Produits, Stock)
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
# Compatible Git Bash / WSL sous Windows.
set -e
echo "Application des fichiers Phase 2..."

mkdir -p "app/Enums"
cat > "app/Enums/ProductUnit.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Enums;

enum ProductUnit: string
{
    case Unite = 'unite';
    case Kg = 'kg';
    case G = 'g';
    case Litre = 'litre';
    case Ml = 'ml';
    case Metre = 'metre';
    case Boite = 'boite';
    case Paquet = 'paquet';
    case Autre = 'autre';

    public function label(): string
    {
        return match ($this) {
            self::Unite => 'Unité',
            self::Kg => 'Kilogramme (kg)',
            self::G => 'Gramme (g)',
            self::Litre => 'Litre (L)',
            self::Ml => 'Millilitre (mL)',
            self::Metre => 'Mètre (m)',
            self::Boite => 'Boîte',
            self::Paquet => 'Paquet',
            self::Autre => 'Autre',
        };
    }

    public static function options(): array
    {
        return array_combine(
            array_map(fn (self $u) => $u->value, self::cases()),
            array_map(fn (self $u) => $u->label(), self::cases()),
        );
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Enums"
cat > "app/Enums/StockMovementType.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Enums;

enum StockMovementType: string
{
    case Purchase = 'purchase';
    case Sale = 'sale';
    case Return = 'return';
    case Adjustment = 'adjustment';
    case Loss = 'loss';
    case Correction = 'correction';

    public function label(): string
    {
        return match ($this) {
            self::Purchase => 'Entrée stock (achat)',
            self::Sale => 'Vente',
            self::Return => 'Retour / Annulation',
            self::Adjustment => 'Ajustement',
            self::Loss => 'Perte',
            self::Correction => 'Correction',
        };
    }

    /**
     * Sens naturel du mouvement, utilisé pour l'affichage (+/-).
     * La quantité réelle stockée en base est toujours signée
     * explicitement par l'appelant (voir StockService::record).
     */
    public function isInbound(): bool
    {
        return in_array($this, [self::Purchase, self::Return], true);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/Category.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Category extends Model
{
    use BelongsToCompany, HasFactory, SoftDeletes;

    protected $fillable = ['company_id', 'name', 'description', 'is_active'];

    protected function casts(): array
    {
        return ['is_active' => 'boolean'];
    }

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/Product.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Enums\ProductUnit;
use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Product extends Model
{
    use BelongsToCompany, HasFactory, SoftDeletes;

    protected $fillable = [
        'company_id',
        'category_id',
        'name',
        'sku',
        'barcode',
        'description',
        'purchase_price',
        'selling_price',
        'stock_quantity',
        'minimum_stock',
        'unit',
        'image',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'unit' => ProductUnit::class,
            'purchase_price' => 'decimal:2',
            'selling_price' => 'decimal:2',
            'is_active' => 'boolean',
        ];
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function stockMovements(): HasMany
    {
        return $this->hasMany(StockMovement::class)->latest('created_at');
    }

    public function isLowStock(): bool
    {
        return $this->stock_quantity <= $this->minimum_stock;
    }

    public function isOutOfStock(): bool
    {
        return $this->stock_quantity <= 0;
    }

    public function scopeLowStock(Builder $query): Builder
    {
        return $query->whereColumn('stock_quantity', '<=', 'minimum_stock');
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }

    public function scopeSearch(Builder $query, ?string $term): Builder
    {
        if (! $term) {
            return $query;
        }

        return $query->where(function (Builder $q) use ($term) {
            $q->where('name', 'like', "%{$term}%")
                ->orWhere('sku', 'like', "%{$term}%")
                ->orWhere('barcode', 'like', "%{$term}%");
        });
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/StockMovement.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Enums\StockMovementType;
use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class StockMovement extends Model
{
    use BelongsToCompany;

    public $timestamps = false;

    protected $fillable = [
        'company_id', 'product_id', 'type', 'quantity', 'reason',
        'reference_type', 'reference_id', 'user_id', 'created_at',
    ];

    protected function casts(): array
    {
        return [
            'type' => StockMovementType::class,
            'created_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (self $movement) {
            $movement->created_at ??= now();
        });
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function reference(): MorphTo
    {
        return $this->morphTo();
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Services"
cat > "app/Services/StockService.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Services;

use App\Enums\StockMovementType;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Point de passage UNIQUE pour toute variation de stock.
 *
 * Règle du cahier des charges (§12) : ne jamais modifier stock_quantity
 * silencieusement. Chaque appel crée un StockMovement traçable et met
 * à jour le produit dans la même transaction.
 */
class StockService
{
    /**
     * Enregistre un mouvement de stock et applique la variation au produit.
     *
     * @param  int  $signedQuantity  Négatif pour une sortie, positif pour une entrée.
     * @param  bool  $allowNegative  Si false, lève une exception si le stock deviendrait négatif.
     */
    public function record(
        Product $product,
        StockMovementType $type,
        int $signedQuantity,
        ?string $reason = null,
        ?Model $reference = null,
        ?User $user = null,
        bool $allowNegative = false,
    ): StockMovement {
        return DB::transaction(function () use ($product, $type, $signedQuantity, $reason, $reference, $user, $allowNegative) {
            // Verrouille la ligne produit le temps de la transaction pour
            // éviter une situation de course (deux ventes simultanées).
            $product = Product::whereKey($product->id)->lockForUpdate()->firstOrFail();

            $newQuantity = $product->stock_quantity + $signedQuantity;

            if (! $allowNegative && $newQuantity < 0) {
                throw new RuntimeException("Stock insuffisant pour « {$product->name} ».");
            }

            $movement = StockMovement::create([
                'company_id' => $product->company_id,
                'product_id' => $product->id,
                'type' => $type,
                'quantity' => $signedQuantity,
                'reason' => $reason,
                'reference_type' => $reference?->getMorphClass(),
                'reference_id' => $reference?->getKey(),
                'user_id' => $user?->id ?? Auth::id(),
            ]);

            $product->update(['stock_quantity' => $newQuantity]);

            return $movement;
        });
    }

    /**
     * Ajustement manuel saisi par un utilisateur (correction d'inventaire,
     * perte constatée, entrée de stock hors achat...).
     */
    public function adjust(Product $product, int $signedQuantity, StockMovementType $type, ?string $reason = null): StockMovement
    {
        return $this->record($product, $type, $signedQuantity, $reason, allowNegative: $type === StockMovementType::Correction);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Services"
cat > "app/Services/ProductService.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Services;

use App\Enums\StockMovementType;
use App\Models\Product;
use Illuminate\Support\Facades\DB;

class ProductService
{
    public function __construct(protected StockService $stockService)
    {
    }

    public function create(array $data): Product
    {
        return DB::transaction(function () use ($data) {
            $initialStock = (int) ($data['stock_quantity'] ?? 0);
            unset($data['stock_quantity']);

            /** @var Product $product */
            $product = Product::create([...$data, 'stock_quantity' => 0]);

            if ($initialStock > 0) {
                $this->stockService->record(
                    $product,
                    StockMovementType::Adjustment,
                    $initialStock,
                    'Stock initial'
                );
            }

            return $product->fresh();
        });
    }

    /**
     * Le stock ne se modifie JAMAIS via update() : uniquement via
     * StockService::adjust(), pour rester traçable.
     */
    public function update(Product $product, array $data): Product
    {
        unset($data['stock_quantity']);

        $product->update($data);

        return $product->fresh();
    }

    public function delete(Product $product): void
    {
        $product->update(['is_active' => false]);
        $product->delete();
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Requests"
cat > "app/Http/Requests/StoreCategoryRequest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Requests;

use App\Support\Tenant;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreCategoryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('products.create');
    }

    public function rules(): array
    {
        return [
            'name' => [
                'required', 'string', 'max:255',
                Rule::unique('categories', 'name')->where('company_id', Tenant::id())->whereNull('deleted_at'),
            ],
            'description' => ['nullable', 'string', 'max:1000'],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Requests"
cat > "app/Http/Requests/UpdateCategoryRequest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Requests;

use App\Support\Tenant;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateCategoryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('products.update');
    }

    public function rules(): array
    {
        return [
            'name' => [
                'required', 'string', 'max:255',
                Rule::unique('categories', 'name')
                    ->where('company_id', Tenant::id())
                    ->whereNull('deleted_at')
                    ->ignore($this->route('category')),
            ],
            'description' => ['nullable', 'string', 'max:1000'],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Requests"
cat > "app/Http/Requests/StoreProductRequest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Requests;

use App\Enums\ProductUnit;
use App\Support\Tenant;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('products.create');
    }

    public function rules(): array
    {
        return [
            'category_id' => [
                'nullable',
                Rule::exists('categories', 'id')->where('company_id', Tenant::id()),
            ],
            'name' => ['required', 'string', 'max:255'],
            'sku' => [
                'nullable', 'string', 'max:100',
                Rule::unique('products', 'sku')->where('company_id', Tenant::id())->whereNull('deleted_at'),
            ],
            'barcode' => ['nullable', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:2000'],
            'purchase_price' => ['required', 'numeric', 'min:0'],
            'selling_price' => ['required', 'numeric', 'min:0'],
            'stock_quantity' => ['nullable', 'integer', 'min:0'],
            'minimum_stock' => ['nullable', 'integer', 'min:0'],
            'unit' => ['required', Rule::in(array_column(ProductUnit::cases(), 'value'))],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }

    public function attributes(): array
    {
        return [
            'category_id' => 'catégorie',
            'purchase_price' => "prix d'achat",
            'selling_price' => 'prix de vente',
            'stock_quantity' => 'stock initial',
            'minimum_stock' => 'stock minimum',
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Requests"
cat > "app/Http/Requests/UpdateProductRequest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Requests;

use App\Enums\ProductUnit;
use App\Support\Tenant;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('products.update');
    }

    public function rules(): array
    {
        return [
            'category_id' => [
                'nullable',
                Rule::exists('categories', 'id')->where('company_id', Tenant::id()),
            ],
            'name' => ['required', 'string', 'max:255'],
            'sku' => [
                'nullable', 'string', 'max:100',
                Rule::unique('products', 'sku')
                    ->where('company_id', Tenant::id())
                    ->whereNull('deleted_at')
                    ->ignore($this->route('product')),
            ],
            'barcode' => ['nullable', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:2000'],
            'purchase_price' => ['required', 'numeric', 'min:0'],
            'selling_price' => ['required', 'numeric', 'min:0'],
            // Le stock ne se modifie pas ici : voir StockController@adjust.
            'minimum_stock' => ['nullable', 'integer', 'min:0'],
            'unit' => ['required', Rule::in(array_column(ProductUnit::cases(), 'value'))],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }

    public function attributes(): array
    {
        return [
            'category_id' => 'catégorie',
            'purchase_price' => "prix d'achat",
            'selling_price' => 'prix de vente',
            'minimum_stock' => 'stock minimum',
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Requests"
cat > "app/Http/Requests/AdjustStockRequest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Requests;

use App\Enums\StockMovementType;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class AdjustStockRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('stock.manage');
    }

    public function rules(): array
    {
        return [
            'type' => ['required', Rule::in(['purchase', 'loss', 'correction'])],
            // Toujours saisie en positif par l'utilisateur ; le sens
            // (entrée/sortie) est déterminé par le type, jamais par le
            // signe envoyé par le navigateur.
            'quantity' => ['required', 'integer', 'min:1'],
            'reason' => ['nullable', 'string', 'max:255'],
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/CategoryController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreCategoryRequest;
use App\Http\Requests\UpdateCategoryRequest;
use App\Models\Category;

class CategoryController extends Controller
{
    public function index()
    {
        $this->authorize('products.view');

        $categories = Category::withCount('products')
            ->orderBy('name')
            ->paginate(20);

        return view('categories.index', compact('categories'));
    }

    public function store(StoreCategoryRequest $request)
    {
        Category::create($request->validated());

        return back()->with('status', 'Catégorie ajoutée.');
    }

    public function update(UpdateCategoryRequest $request, Category $category)
    {
        $category->update($request->validated());

        return back()->with('status', 'Catégorie mise à jour.');
    }

    public function destroy(Category $category)
    {
        $this->authorize('products.delete');

        if ($category->products()->exists()) {
            return back()->withErrors([
                'category' => "Impossible de supprimer « {$category->name} » : des produits y sont rattachés.",
            ]);
        }

        $category->delete();

        return back()->with('status', 'Catégorie supprimée.');
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/ProductController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreProductRequest;
use App\Http\Requests\UpdateProductRequest;
use App\Models\Category;
use App\Models\Product;
use App\Services\ProductService;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $this->authorize('products.view');

        $products = Product::with('category')
            ->search($request->string('q')->toString())
            ->when($request->boolean('low_stock'), fn ($q) => $q->lowStock())
            ->when($request->filled('category_id'), fn ($q) => $q->where('category_id', $request->integer('category_id')))
            ->orderBy('name')
            ->paginate(15)
            ->withQueryString();

        $categories = Category::orderBy('name')->get();
        $lowStockCount = Product::active()->lowStock()->count();

        return view('products.index', compact('products', 'categories', 'lowStockCount'));
    }

    public function create()
    {
        $this->authorize('products.create');

        $categories = Category::active()->orderBy('name')->get();

        return view('products.create', compact('categories'));
    }

    public function store(StoreProductRequest $request, ProductService $productService)
    {
        $productService->create($request->validated());

        return redirect()->route('products.index')->with('status', 'Produit ajouté.');
    }

    public function edit(Product $product)
    {
        $this->authorize('products.update');

        $categories = Category::active()->orderBy('name')->get();

        return view('products.edit', compact('product', 'categories'));
    }

    public function update(UpdateProductRequest $request, Product $product, ProductService $productService)
    {
        $productService->update($product, $request->validated());

        return redirect()->route('products.index')->with('status', 'Produit mis à jour.');
    }

    public function destroy(Product $product, ProductService $productService)
    {
        $this->authorize('products.delete');

        $productService->delete($product);

        return back()->with('status', 'Produit supprimé.');
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/StockController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Enums\StockMovementType;
use App\Http\Requests\AdjustStockRequest;
use App\Models\Product;
use App\Models\StockMovement;
use App\Services\StockService;
use Illuminate\Http\Request;
use RuntimeException;

class StockController extends Controller
{
    public function index(Request $request)
    {
        $this->authorize('stock.view');

        $movements = StockMovement::with(['product', 'user'])
            ->when($request->filled('product_id'), fn ($q) => $q->where('product_id', $request->integer('product_id')))
            ->latest('created_at')
            ->paginate(20)
            ->withQueryString();

        $lowStockProducts = Product::active()->lowStock()->orderBy('stock_quantity')->get();
        $products = Product::active()->orderBy('name')->get();

        return view('stock.index', compact('movements', 'lowStockProducts', 'products'));
    }

    public function adjust(AdjustStockRequest $request, Product $product, StockService $stockService)
    {
        $this->authorize('stock.manage');

        $type = StockMovementType::from($request->validated('type'));
        $quantity = $request->validated('quantity');

        // Le sens du mouvement dépend du TYPE choisi côté serveur, jamais
        // d'un signe envoyé par le formulaire : un achat est toujours une
        // entrée, une perte est toujours une sortie.
        $signedQuantity = $type === StockMovementType::Loss ? -$quantity : $quantity;

        try {
            $stockService->adjust($product, $signedQuantity, $type, $request->validated('reason'));
        } catch (RuntimeException $e) {
            return back()->withErrors(['quantity' => $e->getMessage()]);
        }

        return back()->with('status', "Stock de « {$product->name} » mis à jour.");
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/migrations"
cat > "database/migrations/2026_01_02_000001_create_categories_table.php" << 'PARALLELIUM_FILE_EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('categories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('description')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();

            $table->index(['company_id', 'is_active']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('categories');
    }
};
PARALLELIUM_FILE_EOF

mkdir -p "database/migrations"
cat > "database/migrations/2026_01_02_000002_create_products_table.php" << 'PARALLELIUM_FILE_EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('category_id')->nullable()->constrained()->nullOnDelete();
            $table->string('name');
            $table->string('sku')->nullable();
            $table->string('barcode')->nullable();
            $table->text('description')->nullable();
            $table->decimal('purchase_price', 14, 2)->default(0);
            $table->decimal('selling_price', 14, 2)->default(0);
            // Le stock n'est JAMAIS modifié directement en dehors de
            // StockService : chaque changement crée un stock_movement
            // (voir §12 du cahier des charges).
            $table->integer('stock_quantity')->default(0);
            $table->integer('minimum_stock')->default(0);
            $table->string('unit')->default('unite');
            $table->string('image')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();

            $table->index(['company_id', 'is_active']);
            $table->index(['company_id', 'sku']);
            $table->index(['company_id', 'barcode']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
PARALLELIUM_FILE_EOF

mkdir -p "database/migrations"
cat > "database/migrations/2026_01_02_000003_create_stock_movements_table.php" << 'PARALLELIUM_FILE_EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stock_movements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('product_id')->constrained()->cascadeOnDelete();
            $table->string('type'); // purchase | sale | return | adjustment | loss | correction
            // Quantité SIGNÉE (négative pour une sortie, positive pour une entrée).
            // C'est la seule façon dont stock_quantity peut changer.
            $table->integer('quantity');
            $table->string('reason')->nullable();
            $table->string('reference_type')->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['company_id', 'product_id', 'created_at']);
            $table->index(['reference_type', 'reference_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_movements');
    }
};
PARALLELIUM_FILE_EOF

mkdir -p "database/factories"
cat > "database/factories/CategoryFactory.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Factories;

use App\Models\Category;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Category>
 */
class CategoryFactory extends Factory
{
    protected $model = Category::class;

    public function definition(): array
    {
        return [
            'name' => fake()->unique()->words(2, true),
            'is_active' => true,
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/factories"
cat > "database/factories/ProductFactory.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Factories;

use App\Models\Product;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Product>
 */
class ProductFactory extends Factory
{
    protected $model = Product::class;

    public function definition(): array
    {
        $purchase = fake()->numberBetween(1000, 20000);

        return [
            'name' => fake()->unique()->words(3, true),
            'sku' => strtoupper(fake()->bothify('SKU-####')),
            'purchase_price' => $purchase,
            'selling_price' => $purchase * 1.4,
            'stock_quantity' => fake()->numberBetween(0, 100),
            'minimum_stock' => 5,
            'unit' => 'unite',
            'is_active' => true,
        ];
    }

    public function lowStock(): static
    {
        return $this->state(fn () => [
            'stock_quantity' => 2,
            'minimum_stock' => 5,
        ]);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "tests/Feature"
cat > "tests/Feature/ProductStockTest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Tests\Feature;

use App\Enums\StockMovementType;
use App\Models\Company;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Services\ProductService;
use App\Services\StockService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use RuntimeException;
use Tests\TestCase;

class ProductStockTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([PermissionSeeder::class, RoleSeeder::class]);
    }

    protected function ownerFor(Company $company): User
    {
        $role = Role::whereNull('company_id')->where('slug', 'owner')->first();

        return User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);
    }

    public function test_creating_a_product_with_initial_stock_records_a_stock_movement(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = app(ProductService::class)->create([
            'company_id' => $company->id,
            'name' => 'Riz local 1kg',
            'unit' => 'kg',
            'purchase_price' => 2800,
            'selling_price' => 3500,
            'stock_quantity' => 50,
            'minimum_stock' => 10,
        ]);

        $this->assertEquals(50, $product->stock_quantity);
        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $product->id,
            'quantity' => 50,
            'type' => 'adjustment',
        ]);
    }

    public function test_stock_cannot_go_negative_without_allow_negative(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 3]);

        $this->expectException(RuntimeException::class);

        app(StockService::class)->record($product, StockMovementType::Sale, -5);
    }

    public function test_stock_movement_updates_product_quantity_and_is_traceable(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10]);

        app(StockService::class)->record($product, StockMovementType::Loss, -2, 'Casse');

        $this->assertEquals(8, $product->fresh()->stock_quantity);
        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $product->id,
            'quantity' => -2,
            'reason' => 'Casse',
        ]);
    }

    public function test_a_company_cannot_see_another_companys_products(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();

        Product::factory()->create(['company_id' => $companyA->id, 'name' => 'Produit A']);
        Product::factory()->create(['company_id' => $companyB->id, 'name' => 'Produit B']);

        $userA = $this->ownerFor($companyA);
        $this->actingAs($userA);

        $products = Product::all();

        $this->assertCount(1, $products);
        $this->assertEquals('Produit A', $products->first()->name);
    }

    public function test_low_stock_scope_returns_only_products_under_minimum(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 50, 'minimum_stock' => 10]);
        $low = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 2, 'minimum_stock' => 10]);

        $result = Product::lowStock()->get();

        $this->assertCount(1, $result);
        $this->assertEquals($low->id, $result->first()->id);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/categories"
cat > "resources/views/categories/index.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Catégories">
    <div class="mb-5 flex items-center justify-between">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Catégories</h2>
            <p class="text-sm text-slate-500">Organisez vos produits par catégorie.</p>
        </div>

        <div x-data="{ open: false }">
            <x-button @click="open = true" size="sm">
                <x-icon name="plus" /> Nouvelle catégorie
            </x-button>

            <div x-show="open" x-cloak class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 p-4">
                <div x-show="open" x-on:click.outside="open = false" x-transition class="w-full max-w-sm rounded-2xl bg-white p-5 shadow-xl">
                    <h3 class="mb-4 text-base font-semibold text-slate-800">Nouvelle catégorie</h3>
                    <form method="POST" action="{{ route('categories.store') }}" class="space-y-3">
                        @csrf
                        <div>
                            <x-label for="name">Nom</x-label>
                            <x-input id="name" name="name" required autofocus />
                        </div>
                        <div>
                            <x-label for="description">Description (optionnel)</x-label>
                            <x-input id="description" name="description" />
                        </div>
                        <div class="flex justify-end gap-2 pt-2">
                            <x-button type="button" variant="ghost" @click="open = false">Annuler</x-button>
                            <x-button type="submit">Enregistrer</x-button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>

    @if ($errors->any())
        <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
    @endif

    @if ($categories->isEmpty())
        <x-empty-state
            icon="products"
            title="Aucune catégorie pour le moment."
            description="Créez votre première catégorie pour organiser vos produits." />
    @else
        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            @foreach ($categories as $category)
                <x-card x-data="{ editing: false }">
                    <div x-show="!editing">
                        <div class="flex items-start justify-between">
                            <div>
                                <p class="font-semibold text-slate-800">{{ $category->name }}</p>
                                @if ($category->description)
                                    <p class="mt-0.5 text-sm text-slate-500">{{ $category->description }}</p>
                                @endif
                            </div>
                            <x-badge tone="brand">{{ $category->products_count }} produit{{ $category->products_count > 1 ? 's' : '' }}</x-badge>
                        </div>

                        <div class="mt-4 flex items-center gap-3 text-sm">
                            <button type="button" x-on:click="editing = true" class="font-medium text-brand-600 hover:underline">Modifier</button>
                            <form method="POST" action="{{ route('categories.destroy', $category) }}" onsubmit="return confirm('Supprimer cette catégorie ?');">
                                @csrf
                                @method('DELETE')
                                <button type="submit" class="font-medium text-red-500 hover:underline">Supprimer</button>
                            </form>
                        </div>
                    </div>

                    <form x-show="editing" x-cloak method="POST" action="{{ route('categories.update', $category) }}" class="space-y-2">
                        @csrf
                        @method('PUT')
                        <x-input name="name" value="{{ $category->name }}" required />
                        <x-input name="description" value="{{ $category->description }}" placeholder="Description" />
                        <div class="flex justify-end gap-2 pt-1">
                            <x-button type="button" variant="ghost" size="sm" x-on:click="editing = false">Annuler</x-button>
                            <x-button type="submit" size="sm">Enregistrer</x-button>
                        </div>
                    </form>
                </x-card>
            @endforeach
        </div>

        <div class="mt-5">{{ $categories->links() }}</div>
    @endif
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/products"
cat > "resources/views/products/index.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Produits">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Produits</h2>
            <p class="text-sm text-slate-500">{{ $products->total() }} produit{{ $products->total() > 1 ? 's' : '' }} au catalogue.</p>
        </div>

        <div class="flex items-center gap-2">
            <x-button :href="route('categories.index')" variant="secondary" size="sm">Catégories</x-button>
            <x-button :href="route('products.create')" size="sm"><x-icon name="plus" /> Ajouter un produit</x-button>
        </div>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif

    @if ($lowStockCount > 0)
        <x-alert type="warning" class="mb-4">
            {{ $lowStockCount }} produit{{ $lowStockCount > 1 ? 's ont' : ' a' }} un stock faible ou épuisé.
            <a href="{{ route('products.index', ['low_stock' => 1]) }}" class="font-semibold underline">Voir</a>
        </x-alert>
    @endif

    <form method="GET" class="mb-4 flex flex-wrap items-center gap-2">
        <div class="relative flex-1 min-w-[200px]">
            <x-icon name="search" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <x-input name="q" value="{{ request('q') }}" placeholder="Rechercher un produit, SKU, code-barres..." class="pl-10" />
        </div>

        <select name="category_id" class="rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400" onchange="this.form.submit()">
            <option value="">Toutes les catégories</option>
            @foreach ($categories as $category)
                <option value="{{ $category->id }}" @selected(request('category_id') == $category->id)>{{ $category->name }}</option>
            @endforeach
        </select>

        <label class="flex items-center gap-2 rounded-xl border border-slate-200 px-3 py-2.5 text-sm text-slate-600">
            <input type="checkbox" name="low_stock" value="1" @checked(request('low_stock')) onchange="this.form.submit()" class="rounded border-slate-300 text-brand-600 focus:ring-brand-400">
            Stock faible uniquement
        </label>

        <x-button type="submit" variant="ghost" size="sm">Filtrer</x-button>
    </form>

    @if ($products->isEmpty())
        <x-empty-state icon="products" title="Aucun produit pour le moment." description="Ajoutez votre premier produit pour commencer à gérer votre stock.">
            <x-slot:action>
                <x-button :href="route('products.create')">Ajouter un produit</x-button>
            </x-slot:action>
        </x-empty-state>
    @else
        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            @foreach ($products as $product)
                <x-card>
                    <div class="flex items-start justify-between gap-2">
                        <div class="min-w-0">
                            <p class="truncate font-semibold text-slate-800">{{ $product->name }}</p>
                            <p class="text-xs text-slate-400">{{ $product->category?->name ?? 'Sans catégorie' }} · {{ $product->sku ?? 'Pas de SKU' }}</p>
                        </div>
                        @if ($product->isOutOfStock())
                            <x-badge tone="danger">Épuisé</x-badge>
                        @elseif ($product->isLowStock())
                            <x-badge tone="warning">Stock faible</x-badge>
                        @endif
                    </div>

                    <div class="mt-3 flex items-end justify-between">
                        <div>
                            <p class="text-lg font-bold text-slate-900"><x-money :amount="$product->selling_price" /></p>
                            <p class="text-xs text-slate-400">Achat : <x-money :amount="$product->purchase_price" /></p>
                        </div>
                        <p class="text-sm font-medium text-slate-600">
                            {{ $product->stock_quantity }} {{ $product->unit->label() }}
                        </p>
                    </div>

                    <div class="mt-4 flex items-center gap-3 border-t border-slate-100 pt-3 text-sm">
                        <a href="{{ route('products.edit', $product) }}" class="font-medium text-brand-600 hover:underline">Modifier</a>
                        <a href="{{ route('stock.index', ['product_id' => $product->id]) }}" class="font-medium text-slate-500 hover:underline">Mouvements</a>
                        <form method="POST" action="{{ route('products.destroy', $product) }}" onsubmit="return confirm('Supprimer ce produit ?');" class="ml-auto">
                            @csrf
                            @method('DELETE')
                            <button type="submit" class="font-medium text-red-500 hover:underline">Supprimer</button>
                        </form>
                    </div>
                </x-card>
            @endforeach
        </div>

        <div class="mt-5">{{ $products->links() }}</div>
    @endif
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/products"
cat > "resources/views/products/create.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Nouveau produit">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Nouveau produit</h2>
        <p class="text-sm text-slate-500">Le stock initial sera enregistré comme un mouvement traçable.</p>
    </div>

    @if ($errors->any())
        <x-alert type="error" class="mb-4">
            <ul class="list-inside list-disc space-y-1">
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </x-alert>
    @endif

    <x-card>
        <form method="POST" action="{{ route('products.store') }}">
            @php($product = null)
            @include('products._form')
        </form>
    </x-card>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/products"
cat > "resources/views/products/edit.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Modifier le produit">
    <div class="mb-5 flex items-center justify-between">
        <div>
            <h2 class="text-xl font-bold text-slate-900">{{ $product->name }}</h2>
            <p class="text-sm text-slate-500">
                Stock actuel : {{ $product->stock_quantity }} {{ $product->unit->label() }} —
                <a href="{{ route('stock.index', ['product_id' => $product->id]) }}" class="font-medium text-brand-600 hover:underline">ajuster le stock</a>
            </p>
        </div>
    </div>

    @if ($errors->any())
        <x-alert type="error" class="mb-4">
            <ul class="list-inside list-disc space-y-1">
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </x-alert>
    @endif

    <x-card>
        <form method="POST" action="{{ route('products.update', $product) }}">
            @include('products._form')
        </form>
    </x-card>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/products"
cat > "resources/views/products/_form.blade.php" << 'PARALLELIUM_FILE_EOF'
@csrf
@if ($product ?? null)
    @method('PUT')
@endif

<div class="grid gap-4 sm:grid-cols-2">
    <div class="sm:col-span-2">
        <x-label for="name">Nom du produit</x-label>
        <x-input id="name" name="name" value="{{ old('name', $product->name ?? '') }}" required autofocus />
    </div>

    <div>
        <x-label for="category_id">Catégorie</x-label>
        <select id="category_id" name="category_id" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">
            <option value="">Sans catégorie</option>
            @foreach ($categories as $category)
                <option value="{{ $category->id }}" @selected(old('category_id', $product->category_id ?? null) == $category->id)>{{ $category->name }}</option>
            @endforeach
        </select>
    </div>

    <div>
        <x-label for="unit">Unité</x-label>
        <select id="unit" name="unit" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">
            @foreach (\App\Enums\ProductUnit::options() as $value => $label)
                <option value="{{ $value }}" @selected(old('unit', $product->unit->value ?? 'unite') === $value)>{{ $label }}</option>
            @endforeach
        </select>
    </div>

    <div>
        <x-label for="sku">SKU (référence interne)</x-label>
        <x-input id="sku" name="sku" value="{{ old('sku', $product->sku ?? '') }}" placeholder="Optionnel" />
    </div>

    <div>
        <x-label for="barcode">Code-barres</x-label>
        <x-input id="barcode" name="barcode" value="{{ old('barcode', $product->barcode ?? '') }}" placeholder="Optionnel" />
    </div>

    <div>
        <x-label for="purchase_price">Prix d'achat</x-label>
        <x-input id="purchase_price" type="number" step="0.01" min="0" name="purchase_price" value="{{ old('purchase_price', $product->purchase_price ?? 0) }}" required />
    </div>

    <div>
        <x-label for="selling_price">Prix de vente</x-label>
        <x-input id="selling_price" type="number" step="0.01" min="0" name="selling_price" value="{{ old('selling_price', $product->selling_price ?? 0) }}" required />
    </div>

    @unless ($product ?? null)
        <div>
            <x-label for="stock_quantity">Stock initial</x-label>
            <x-input id="stock_quantity" type="number" min="0" name="stock_quantity" value="{{ old('stock_quantity', 0) }}" />
        </div>
    @endunless

    <div>
        <x-label for="minimum_stock">Stock minimum (alerte)</x-label>
        <x-input id="minimum_stock" type="number" min="0" name="minimum_stock" value="{{ old('minimum_stock', $product->minimum_stock ?? 5) }}" />
    </div>

    <div class="sm:col-span-2">
        <x-label for="description">Description</x-label>
        <textarea id="description" name="description" rows="3" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">{{ old('description', $product->description ?? '') }}</textarea>
    </div>
</div>

<div class="mt-6 flex items-center gap-3">
    <x-button type="submit">{{ ($product ?? null) ? 'Enregistrer les modifications' : 'Ajouter le produit' }}</x-button>
    <x-button :href="route('products.index')" variant="ghost" type="button">Annuler</x-button>
</div>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/stock"
cat > "resources/views/stock/index.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Stock">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Stock</h2>
            <p class="text-sm text-slate-500">Historique des mouvements et alertes de stock faible.</p>
        </div>

        <div x-data="{ open: false, productId: '{{ request('product_id') }}' }">
            <x-button @click="open = true" size="sm"><x-icon name="plus" /> Ajuster un stock</x-button>

            <div x-show="open" x-cloak class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 p-4">
                <div x-show="open" x-on:click.outside="open = false" x-transition class="w-full max-w-sm rounded-2xl bg-white p-5 shadow-xl">
                    <h3 class="mb-4 text-base font-semibold text-slate-800">Ajuster un stock</h3>

                    <form method="POST" x-bind:action="productId ? '/stock/' + productId + '/adjust' : '#'" class="space-y-3">
                        @csrf
                        <div>
                            <x-label for="adjust_product">Produit</x-label>
                            <select id="adjust_product" x-model="productId" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400" required>
                                <option value="">Sélectionner...</option>
                                @foreach ($products as $product)
                                    <option value="{{ $product->id }}">{{ $product->name }} ({{ $product->stock_quantity }} {{ $product->unit->label() }})</option>
                                @endforeach
                            </select>
                        </div>

                        <div>
                            <x-label for="type">Type de mouvement</x-label>
                            <select id="type" name="type" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400" required>
                                <option value="purchase">Entrée de stock (achat)</option>
                                <option value="loss">Perte</option>
                                <option value="correction">Correction d'inventaire</option>
                            </select>
                        </div>

                        <div>
                            <x-label for="quantity">Quantité</x-label>
                            <x-input id="quantity" type="number" min="1" name="quantity" required />
                        </div>

                        <div>
                            <x-label for="reason">Motif (optionnel)</x-label>
                            <x-input id="reason" name="reason" placeholder="Ex. Réception fournisseur" />
                        </div>

                        <div class="flex justify-end gap-2 pt-2">
                            <x-button type="button" variant="ghost" @click="open = false">Annuler</x-button>
                            <x-button type="submit">Enregistrer</x-button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif
    @if ($errors->any())
        <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
    @endif

    @if ($lowStockProducts->isNotEmpty())
        <x-card class="mb-5">
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Produits en stock faible</h3>
            <div class="flex flex-wrap gap-2">
                @foreach ($lowStockProducts as $product)
                    <a href="{{ route('stock.index', ['product_id' => $product->id]) }}"
                       class="flex items-center gap-2 rounded-full border border-amber-200 bg-amber-50 px-3 py-1.5 text-xs font-medium text-amber-800">
                        {{ $product->name }}
                        <span class="rounded-full bg-amber-200 px-1.5">{{ $product->stock_quantity }}</span>
                    </a>
                @endforeach
            </div>
        </x-card>
    @endif

    @if (request('product_id'))
        <div class="mb-3">
            <a href="{{ route('stock.index') }}" class="text-sm font-medium text-brand-600 hover:underline">&larr; Voir tous les mouvements</a>
        </div>
    @endif

    @if ($movements->isEmpty())
        <x-empty-state icon="stock" title="Aucun mouvement de stock." description="Les entrées, ventes et ajustements de stock apparaîtront ici, chacun tracé individuellement." />
    @else
        <x-card :padded="false">
            <div class="divide-y divide-slate-100">
                @foreach ($movements as $movement)
                    <div class="flex items-center justify-between gap-3 px-5 py-3">
                        <div class="min-w-0">
                            <p class="truncate text-sm font-medium text-slate-800">{{ $movement->product->name }}</p>
                            <p class="text-xs text-slate-400">
                                {{ $movement->type->label() }}
                                @if ($movement->reason) · {{ $movement->reason }} @endif
                                · {{ $movement->created_at->format('d/m/Y H:i') }}
                                @if ($movement->user) · {{ $movement->user->name }} @endif
                            </p>
                        </div>
                        <span class="shrink-0 text-sm font-bold {{ $movement->quantity >= 0 ? 'text-emerald-600' : 'text-red-500' }}">
                            {{ $movement->quantity >= 0 ? '+' : '' }}{{ $movement->quantity }}
                        </span>
                    </div>
                @endforeach
            </div>
        </x-card>

        <div class="mt-5">{{ $movements->links() }}</div>
    @endif
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "routes"
cat > "routes/web.php" << 'PARALLELIUM_FILE_EOF'
<?php

use App\Http\Controllers\Auth\AuthenticatedSessionController;
use App\Http\Controllers\Auth\NewPasswordController;
use App\Http\Controllers\Auth\PasswordResetLinkController;
use App\Http\Controllers\Auth\RegisteredCompanyController;
use App\Http\Controllers\CategoryController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\OnboardingController;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\StockController;
use Illuminate\Support\Facades\Route;

Route::redirect('/', '/login');

// --- Invités ---
Route::middleware('guest')->group(function () {
    Route::get('register', [RegisteredCompanyController::class, 'create'])->name('register');
    Route::post('register', [RegisteredCompanyController::class, 'store']);

    Route::get('login', [AuthenticatedSessionController::class, 'create'])->name('login');
    Route::post('login', [AuthenticatedSessionController::class, 'store']);

    Route::get('forgot-password', [PasswordResetLinkController::class, 'create'])->name('password.request');
    Route::post('forgot-password', [PasswordResetLinkController::class, 'store'])->name('password.email');

    Route::get('reset-password/{token}', [NewPasswordController::class, 'create'])->name('password.reset');
    Route::post('reset-password', [NewPasswordController::class, 'store'])->name('password.store');
});

// --- Authentifiés ---
Route::middleware('auth')->group(function () {
    Route::post('logout', [AuthenticatedSessionController::class, 'destroy'])->name('logout');

    Route::prefix('onboarding')->name('onboarding.')->group(function () {
        Route::get('/', [OnboardingController::class, 'show'])->name('show');
        Route::put('/', [OnboardingController::class, 'update'])->name('update');
        Route::post('finish', [OnboardingController::class, 'finish'])->name('finish');
        Route::post('skip', [OnboardingController::class, 'skip'])->name('skip');
    });

    Route::middleware('onboarding')->group(function () {
        Route::get('dashboard', DashboardController::class)->name('dashboard');

        Route::resource('categories', CategoryController::class)->only(['index', 'store', 'update', 'destroy']);

        Route::resource('products', ProductController::class)->except(['show']);

        Route::get('stock', [StockController::class, 'index'])->name('stock.index');
        Route::post('stock/{product}/adjust', [StockController::class, 'adjust'])->name('stock.adjust');

        // Les modules suivants (clients, ventes, dépenses, factures,
        // rapports, employés, paramètres) sont ajoutés phase par phase —
        // voir le cahier des charges §56.
    });
});
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/DashboardController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Support\Tenant;

class DashboardController extends Controller
{
    public function __invoke()
    {
        $company = Tenant::current();

        // Les modules Ventes/Dépenses/Clients arrivent en Phase 3 à 7 :
        // ces indicateurs restent à zéro, jamais de données fictives, en
        // attendant que ces modules existent. Produits/Stock (Phase 2)
        // alimentent désormais réellement le dashboard.
        $kpis = [
            'revenue_today' => 0,
            'revenue_month' => 0,
            'expenses_month' => 0,
            'estimated_result' => 0,
            'low_stock_count' => Product::active()->lowStock()->count(),
            'receivables' => 0,
            'customers_count' => 0,
        ];

        $lowStockProducts = Product::active()->lowStock()->orderBy('stock_quantity')->limit(5)->get();

        return view('dashboard', compact('company', 'kpis', 'lowStockProducts'));
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "resources/views"
cat > "resources/views/dashboard.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Tableau de bord">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Bonjour {{ explode(' ', auth()->user()->name)[0] }}</h2>
        <p class="text-sm text-slate-500">Voici un aperçu de {{ $company->name }}.</p>
    </div>

    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <x-stat-card label="Chiffre d'affaires (jour)" :value="\App\Support\Money::format($kpis['revenue_today'])" icon="money" />
        <x-stat-card label="Chiffre d'affaires (mois)" :value="\App\Support\Money::format($kpis['revenue_month'])" icon="revenue" />
        <x-stat-card label="Dépenses (mois)" :value="\App\Support\Money::format($kpis['expenses_month'])" icon="expenses" />
        <x-stat-card label="Résultat estimé" :value="\App\Support\Money::format($kpis['estimated_result'])" tone="brand" icon="result" />
    </div>

    <p class="mt-3 text-xs text-slate-400">
        Le résultat affiché est un indicateur de gestion interne, pas un résultat comptable officiel.
    </p>

    <div class="mt-6 grid gap-4 lg:grid-cols-3">
        <x-card class="lg:col-span-2">
            <div class="flex items-center justify-between">
                <h3 class="text-sm font-semibold text-slate-700">Dernières ventes</h3>
            </div>

            <x-empty-state
                class="mt-4"
                icon="sales"
                title="Aucune vente pour le moment."
                description="Le module Ventes arrive en Phase 4. Vos ventes récentes apparaîtront ici automatiquement.">
            </x-empty-state>
        </x-card>

        <x-card>
            <h3 class="text-sm font-semibold text-slate-700">Stock faible</h3>
            @if ($lowStockProducts->isEmpty())
                <x-empty-state
                    class="mt-4"
                    icon="package"
                    title="Aucune alerte de stock."
                    description="Vous serez averti ici dès qu'un produit passera sous son seuil minimum." />
            @else
                <div class="mt-3 space-y-2">
                    @foreach ($lowStockProducts as $product)
                        <a href="{{ route('stock.index', ['product_id' => $product->id]) }}" class="flex items-center justify-between rounded-xl border border-amber-100 bg-amber-50 px-3 py-2 text-sm">
                            <span class="font-medium text-amber-900">{{ $product->name }}</span>
                            <span class="text-amber-700">{{ $product->stock_quantity }} / {{ $product->minimum_stock }}</span>
                        </a>
                    @endforeach
                </div>
                <a href="{{ route('products.index', ['low_stock' => 1]) }}" class="mt-3 block text-center text-xs font-medium text-brand-600 hover:underline">
                    Voir tous les produits en stock faible
                </a>
            @endif
        </x-card>
    </div>

    <div class="mt-4 grid gap-4 lg:grid-cols-2">
        <x-card>
            <h3 class="text-sm font-semibold text-slate-700">Créances clients</h3>
            <x-empty-state class="mt-4" icon="customers" title="Aucun client pour le moment." description="Le module Clients arrive en Phase 3." />
        </x-card>

        <x-card>
            <h3 class="text-sm font-semibold text-slate-700">Dernières dépenses</h3>
            <x-empty-state class="mt-4" icon="expenses" title="Aucune dépense pour le moment." description="Le module Dépenses arrive en Phase 5." />
        </x-card>
    </div>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "database/seeders"
cat > "database/seeders/DemoCompanySeeder.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Company;
use App\Models\Product;
use App\Models\Role;
use App\Models\Subscription;
use App\Models\User;
use App\Services\ProductService;
use Illuminate\Database\Seeder;

/**
 * Jeu de données de démonstration ("Parallelium Demo") pour que le
 * tableau de bord soit immédiatement intéressant après installation.
 * Les données Ventes/Clients/Dépenses seront enrichies au fil des
 * phases 3 à 5 (voir §56 du cahier des charges), quand ces modules
 * existeront réellement.
 */
class DemoCompanySeeder extends Seeder
{
    public function run(): void
    {
        $company = Company::updateOrCreate(
            ['name' => 'Parallelium Demo'],
            [
                'legal_name' => 'Parallelium Demo SARL',
                'email' => 'demo@parallelium.app',
                'phone' => '034 41 853 25',
                'address' => 'Lot II A 12 Bis, Antananarivo',
                'city' => 'Antananarivo',
                'country' => 'Madagascar',
                'currency' => 'MGA',
                'timezone' => 'Indian/Antananarivo',
                'business_type' => 'Commerce de détail',
                'invoice_prefix' => 'PAR',
                'onboarding_completed' => true,
                'status' => 'active',
            ]
        );

        Subscription::updateOrCreate(
            ['company_id' => $company->id],
            ['plan' => 'starter', 'status' => 'active', 'current_period_ends_at' => now()->addMonth()]
        );

        $roles = Role::whereNull('company_id')->pluck('id', 'slug');

        $demoUsers = [
            ['name' => 'Rasoa Andriamamy', 'email' => 'owner@parallelium.demo', 'role' => 'owner'],
            ['name' => 'Nirina Rakoto', 'email' => 'manager@parallelium.demo', 'role' => 'manager'],
            ['name' => 'Fara Randria', 'email' => 'seller@parallelium.demo', 'role' => 'seller'],
        ];

        foreach ($demoUsers as $demoUser) {
            User::updateOrCreate(
                ['email' => $demoUser['email']],
                [
                    'company_id' => $company->id,
                    'role_id' => $roles[$demoUser['role']],
                    'name' => $demoUser['name'],
                    'password' => 'password',
                    'is_active' => true,
                    'email_verified_at' => now(),
                ]
            );
        }

        $this->seedCatalog($company);
    }

    protected function seedCatalog(Company $company): void
    {
        if (Product::withoutTenantScope()->where('company_id', $company->id)->exists()) {
            return; // déjà peuplé, ne pas dupliquer si on reseed
        }

        $categories = [
            'Épicerie' => 'Produits alimentaires de base',
            'Boissons' => 'Boissons fraîches et sèches',
            'Hygiène' => 'Produits d\'hygiène et d\'entretien',
        ];

        $categoryIds = [];
        foreach ($categories as $name => $description) {
            $categoryIds[$name] = Category::create([
                'company_id' => $company->id,
                'name' => $name,
                'description' => $description,
                'is_active' => true,
            ])->id;
        }

        $products = [
            ['name' => 'Riz local 1kg', 'category' => 'Épicerie', 'sku' => 'RIZ-001', 'purchase' => 2800, 'sell' => 3500, 'stock' => 120, 'min' => 20, 'unit' => 'kg'],
            ['name' => 'Huile alimentaire 1L', 'category' => 'Épicerie', 'sku' => 'HUI-001', 'purchase' => 6500, 'sell' => 8000, 'stock' => 40, 'min' => 10, 'unit' => 'litre'],
            ['name' => 'Sucre 1kg', 'category' => 'Épicerie', 'sku' => 'SUC-001', 'purchase' => 3200, 'sell' => 4000, 'stock' => 4, 'min' => 15, 'unit' => 'kg'],
            ['name' => 'Eau minérale 1.5L', 'category' => 'Boissons', 'sku' => 'EAU-001', 'purchase' => 1200, 'sell' => 1800, 'stock' => 96, 'min' => 24, 'unit' => 'unite'],
            ['name' => 'THB 65cl', 'category' => 'Boissons', 'sku' => 'THB-001', 'purchase' => 2500, 'sell' => 3500, 'stock' => 60, 'min' => 12, 'unit' => 'unite'],
            ['name' => 'Savon de Marseille', 'category' => 'Hygiène', 'sku' => 'SAV-001', 'purchase' => 1500, 'sell' => 2200, 'stock' => 3, 'min' => 10, 'unit' => 'unite'],
        ];

        $productService = app(ProductService::class);

        foreach ($products as $p) {
            $productService->create([
                'company_id' => $company->id,
                'category_id' => $categoryIds[$p['category']],
                'name' => $p['name'],
                'sku' => $p['sku'],
                'purchase_price' => $p['purchase'],
                'selling_price' => $p['sell'],
                'stock_quantity' => $p['stock'],
                'minimum_stock' => $p['min'],
                'unit' => $p['unit'],
                'is_active' => true,
            ]);
        }
    }
}
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant :"
echo "  php artisan migrate"
echo "  php artisan db:seed --class=Database\\Seeders\\DemoCompanySeeder"
echo "  php artisan view:clear"
