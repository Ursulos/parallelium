<link rel="manifest" href="<?php echo e(asset('manifest.json')); ?>">
<link rel="apple-touch-icon" href="<?php echo e(asset('icons/apple-touch-icon.png')); ?>">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.6.0/css/all.min.css" integrity="sha512-Kc323vGBEqzTmouAECnVceyQqyqdsSiqLQISBL29aUW4U/M7pSPA/gEUZQqv1cwx4OnYxTxve5UMg5GT6L4JJg==" crossorigin="anonymous" referrerpolicy="no-referrer">
<meta name="theme-color" content="#481f89">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Parallelium">
<script>
    // Enregistrement du service worker + détection de mise à jour.
    // Quand une nouvelle version est prête, on prévient l'utilisateur
    // au lieu de remplacer le SW sous ses pieds (évite un rechargement
    // surprise en pleine saisie d'une vente).
    if ('serviceWorker' in navigator) {
        window.addEventListener('load', () => {
            navigator.serviceWorker.register('/sw.js').then((registration) => {
                registration.addEventListener('updatefound', () => {
                    const worker = registration.installing;
                    if (!worker) return;

                    worker.addEventListener('statechange', () => {
                        if (worker.state === 'installed' && navigator.serviceWorker.controller) {
                            window.dispatchEvent(new CustomEvent('parallelium-update-available', { detail: { registration } }));
                        }
                    });
                });
            }).catch(() => {});

            let refreshing = false;
            navigator.serviceWorker.addEventListener('controllerchange', () => {
                if (refreshing) return;
                refreshing = true;
                window.location.reload();
            });
        });
    }
</script>
<?php /**PATH C:\xampp\htdocs\parallelium\resources\views/components/pwa-head.blade.php ENDPATH**/ ?>