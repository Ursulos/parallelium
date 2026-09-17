<aside class="hidden w-64 shrink-0 flex-col border-r border-slate-100 bg-white px-4 py-6 lg:flex">
    <div class="mb-8 flex items-center gap-2 px-2 text-lg font-extrabold text-brand-800">
        <span class="flex h-8 w-8 items-center justify-center rounded-full bg-brand-gradient text-sm text-white"><x-icon name="logo" /></span>
        Parallelium
    </div>

    <nav class="flex flex-1 flex-col gap-1">
        <x-nav-link route-name="dashboard" icon="home" label="Accueil" />
        <x-nav-link route-name="sales.index" icon="sales" label="Ventes" />
        <x-nav-link route-name="products.index" icon="products" label="Produits" />
        <x-nav-link route-name="stock.index" icon="stock" label="Stock" />
        <x-nav-link route-name="customers.index" icon="customers" label="Clients" />
        <x-nav-link route-name="expenses.index" icon="expenses" label="Dépenses" />
        <x-nav-link route-name="invoices.index" icon="invoices" label="Factures" />
        <x-nav-link route-name="reports.index" icon="reports" label="Rapports" />
        <x-nav-link route-name="employees.index" icon="employees" label="Employés" />
        <x-nav-link route-name="settings.index" icon="settings" label="Paramètres" />
    </nav>

    <div class="mt-4 rounded-xl bg-brand-50 p-3 text-xs text-brand-700">
        <p class="font-semibold">{{ auth()->user()->company->name }}</p>
        <p class="mt-0.5 text-brand-500">Plan {{ ucfirst(auth()->user()->company->subscription->plan ?? 'free') }}</p>
    </div>
</aside>