<?php

/**
 * Catalogues de produits standards proposés à l'inscription (§40, sur
 * demande explicite). L'utilisateur choisit un type de commerce ; on lui
 * propose ensuite d'ajouter cette liste à son catalogue — jamais
 * automatique, toujours un choix explicite (voir OnboardingController).
 *
 * Volontairement SANS prix ni SKU : à l'entrepreneur de les compléter
 * selon son propre fournisseur et sa propre marge. Le stock initial est
 * toujours à 0 (aucune donnée fictive — §51).
 *
 * Les variétés de marque (ex. cigarettes) reflètent des produits
 * réellement vendus à Madagascar, mais les prix/marques évoluent : c'est
 * un point de départ à ajuster, pas une vérité figée.
 */

return [
    'epicerie_ppn' => [
        'label' => 'Épicerie / PPN (Produits de Première Nécessité)',
        'categories' => [
            'Alimentation de base' => [
                ['name' => 'Riz local 1kg', 'unit' => 'kg'],
                ['name' => 'Riz importé 1kg', 'unit' => 'kg'],
                ['name' => 'Huile alimentaire 1L', 'unit' => 'litre'],
                ['name' => 'Sucre blanc 1kg', 'unit' => 'kg'],
                ['name' => 'Sel de cuisine', 'unit' => 'paquet'],
                ['name' => 'Farine de blé 1kg', 'unit' => 'kg'],
                ['name' => 'Pâtes alimentaires', 'unit' => 'paquet'],
                ['name' => 'Lait en poudre', 'unit' => 'boite'],
                ['name' => 'Café moulu', 'unit' => 'paquet'],
                ['name' => 'Thé (sachets)', 'unit' => 'boite'],
                ['name' => 'Sardines en boîte', 'unit' => 'boite'],
                ['name' => 'Corned-beef en boîte', 'unit' => 'boite'],
                ['name' => 'Concentré de tomate', 'unit' => 'boite'],
                ['name' => 'Bonbons assortis', 'unit' => 'paquet'],
                ['name' => 'Biscuits', 'unit' => 'paquet'],
                ['name' => 'Pain', 'unit' => 'unite'],
                ['name' => 'Œufs', 'unit' => 'unite'],
            ],
            'Boissons' => [
                ['name' => 'Eau minérale 1.5L', 'unit' => 'unite'],
                ['name' => 'Eau minérale 0.5L', 'unit' => 'unite'],
                ['name' => 'THB 65cl', 'unit' => 'unite'],
                ['name' => 'Boisson gazeuse 1L', 'unit' => 'unite'],
                ['name' => 'Jus de fruit en sachet', 'unit' => 'unite'],
                ['name' => 'Rhum arrangé (local)', 'unit' => 'litre'],
            ],
            'Hygiène et entretien' => [
                ['name' => 'Savon de Marseille', 'unit' => 'unite'],
                ['name' => 'Savon en poudre (lessive)', 'unit' => 'paquet'],
                ['name' => 'Pâte dentifrice', 'unit' => 'unite'],
                ['name' => 'Papier hygiénique', 'unit' => 'unite'],
                ['name' => 'Allumettes', 'unit' => 'boite'],
                ['name' => 'Bougies', 'unit' => 'paquet'],
                ['name' => 'Pétrole lampant', 'unit' => 'litre'],
                ['name' => 'Charbon de bois', 'unit' => 'kg'],
                ['name' => 'Piles électriques (AA)', 'unit' => 'paquet'],
            ],
            'Cigarettes' => [
                ['name' => 'Good Look', 'unit' => 'paquet'],
                ['name' => 'Good Look (à la tige)', 'unit' => 'unite'],
                ['name' => 'Melia Rouge', 'unit' => 'paquet'],
                ['name' => 'Melia Rouge (à la tige)', 'unit' => 'unite'],
                ['name' => 'First', 'unit' => 'paquet'],
                ['name' => 'First (à la tige)', 'unit' => 'unite'],
                ['name' => 'News Maitso', 'unit' => 'paquet'],
                ['name' => 'News Maitso (à la tige)', 'unit' => 'unite'],
                ['name' => 'News Mena', 'unit' => 'paquet'],
                ['name' => 'News Mena (à la tige)', 'unit' => 'unite'],
                ['name' => 'PS Rouge', 'unit' => 'paquet'],
                ['name' => 'PS Rouge (à la tige)', 'unit' => 'unite'],
            ],
        ],
    ],

    'quincaillerie' => [
        'label' => 'Quincaillerie',
        'categories' => [
            'Outillage' => [
                ['name' => 'Marteau', 'unit' => 'unite'],
                ['name' => 'Tournevis (jeu)', 'unit' => 'unite'],
                ['name' => 'Pince', 'unit' => 'unite'],
                ['name' => 'Scie à métaux', 'unit' => 'unite'],
                ['name' => 'Mètre ruban', 'unit' => 'unite'],
                ['name' => 'Niveau à bulle', 'unit' => 'unite'],
            ],
            'Quincaillerie générale' => [
                ['name' => 'Clous assortis', 'unit' => 'kg'],
                ['name' => 'Vis assorties', 'unit' => 'boite'],
                ['name' => 'Boulons et écrous', 'unit' => 'boite'],
                ['name' => 'Fil de fer', 'unit' => 'kg'],
                ['name' => 'Cadenas', 'unit' => 'unite'],
                ['name' => 'Charnières', 'unit' => 'unite'],
                ['name' => 'Ruban adhésif large', 'unit' => 'unite'],
                ['name' => 'Colle forte', 'unit' => 'unite'],
            ],
            'Peinture et plomberie' => [
                ['name' => 'Peinture (pot 1L)', 'unit' => 'unite'],
                ['name' => 'Pinceau', 'unit' => 'unite'],
                ['name' => 'Tuyau PVC (mètre)', 'unit' => 'metre'],
                ['name' => 'Raccord PVC', 'unit' => 'unite'],
                ['name' => 'Robinet', 'unit' => 'unite'],
                ['name' => 'Ampoule électrique', 'unit' => 'unite'],
                ['name' => 'Câble électrique (mètre)', 'unit' => 'metre'],
            ],
        ],
    ],

    'telephonie_mobile_money' => [
        'label' => 'Téléphonie & Mobile Money',
        'categories' => [
            'Accessoires téléphone' => [
                ['name' => 'Câble de charge USB', 'unit' => 'unite'],
                ['name' => 'Chargeur secteur', 'unit' => 'unite'],
                ['name' => 'Écouteurs filaires', 'unit' => 'unite'],
                ['name' => 'Coque de protection', 'unit' => 'unite'],
                ['name' => 'Protection d\'écran (verre trempé)', 'unit' => 'unite'],
                ['name' => 'Batterie externe (powerbank)', 'unit' => 'unite'],
                ['name' => 'Carte mémoire', 'unit' => 'unite'],
            ],
            'Recharges et cartes SIM' => [
                ['name' => 'Recharge Telma', 'unit' => 'unite'],
                ['name' => 'Recharge Orange', 'unit' => 'unite'],
                ['name' => 'Recharge Airtel', 'unit' => 'unite'],
                ['name' => 'Carte SIM Telma', 'unit' => 'unite'],
                ['name' => 'Carte SIM Orange', 'unit' => 'unite'],
                ['name' => 'Carte SIM Airtel', 'unit' => 'unite'],
            ],
        ],
    ],

    'vetements' => [
        'label' => 'Vêtements et accessoires',
        'categories' => [
            'Vêtements' => [
                ['name' => 'T-shirt homme', 'unit' => 'unite'],
                ['name' => 'T-shirt femme', 'unit' => 'unite'],
                ['name' => 'Chemise', 'unit' => 'unite'],
                ['name' => 'Pantalon', 'unit' => 'unite'],
                ['name' => 'Robe', 'unit' => 'unite'],
                ['name' => 'Jupe', 'unit' => 'unite'],
                ['name' => 'Lamba (traditionnel)', 'unit' => 'unite'],
                ['name' => 'Sous-vêtements', 'unit' => 'unite'],
            ],
            'Chaussures et accessoires' => [
                ['name' => 'Sandales', 'unit' => 'unite'],
                ['name' => 'Chaussures fermées', 'unit' => 'unite'],
                ['name' => 'Ceinture', 'unit' => 'unite'],
                ['name' => 'Casquette', 'unit' => 'unite'],
                ['name' => 'Sac à main', 'unit' => 'unite'],
            ],
        ],
    ],
];
