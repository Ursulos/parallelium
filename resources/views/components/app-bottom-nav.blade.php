<nav class="fixed inset-x-0 bottom-0 z-30 border-t border-slate-100 bg-white/95 backdrop-blur pb-[env(safe-area-inset-bottom)] lg:hidden">
    <div class="relative mx-auto grid max-w-lg grid-cols-5 items-center px-2 py-2">
        <x-bottom-nav-item route-name="dashboard" icon="🏠" label="Accueil" />
        <x-bottom-nav-item route-name="sales.index" icon="💳" label="Ventes" />

        <div class="flex items-center justify-center">
            <button
                type="button"
                x-data
                @click="$dispatch('open-quick-actions')"
                class="-mt-8 flex h-14 w-14 items-center justify-center rounded-full bg-brand-gradient text-2xl font-bold text-white shadow-lg shadow-brand-500/40 active:scale-95 transition">
                +
            </button>
        </div>

        <x-bottom-nav-item route-name="stock.index" icon="📊" label="Stock" />
        <x-bottom-nav-item route-name="customers.index" icon="👥" label="Clients" />
    </div>
</nav>
