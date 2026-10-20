extends Node
## ItemDB — the single source of truth for every item and collectible.
##
## Every Collection Book entry is generated from the compact tables below,
## so adding a new plant is literally a one-line change:
##   ["Name", seasons, rarity, archetype, main_color, accent_color, {options}]
## seasons: "p"=spring "s"=summer "f"=fall "w"=winter "*"=all year
## archetypes control how the plant is drawn and grown (see pixel_art.gd).

const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [Color("d8dccb"), Color("7ed37a"), Color("5aa9ff"), Color("c47dff"), Color("ffc23d")]
const SEASON_NAMES := ["Spring", "Summer", "Fall", "Winter"]
const SEASON_COLORS := [Color("f7a8c4"), Color("ffd45a"), Color("e8873a"), Color("9fd4ff")]
const BASE_VALUE := [24, 60, 150, 400, 1250]
const BASE_DAYS := [3, 4, 6, 8, 11]
const DISCOVER_XP := [15, 30, 60, 120, 300]
const HARVEST_XP := [4, 8, 16, 32, 80]
const FORAGE_WEIGHT := [40.0, 18.0, 7.0, 2.5, 0.8]

## Collection Book tabs: [category id, display name]
const BOOK_TABS := [
	["crop", "Crops"], ["flower", "Flowers"], ["herb", "Herbs"], ["bush", "Bushes"],
	["tree", "Fruit Trees"], ["mushroom", "Mushrooms"], ["exotic", "Exotic"],
	["mythical", "Mythical"], ["crystal", "Crystal"], ["ancient", "Ancient"],
	["seasonal", "Seasonal"], ["mutation", "Golden & Rainbow"], ["tool", "Tools & Supplies"],
	["decor", "Decor"], ["treasure", "Treasures"],
]

const REGION_NAMES := {
	"home": "Home Garden", "village": "Willowbrook Village", "flower_fields": "Flower Fields",
	"forest": "Whispering Forest", "mushroom_caves": "Mushroom Caves", "mountains": "Misty Mountains",
	"fairy_garden": "Fairy Garden", "crystal_biome": "Crystal Hollow", "ancient_ruins": "Ancient Ruins",
	"festival": "Seasonal Festivals",
}

# ---------------------------------------------------------------- PLANT DATA
const CROPS := [
	["Turnip", "p", 0, "root", "f2e6ef", "b05fa0", {"shop": true}],
	["Carrot", "pf", 0, "root", "f08a24", "", {"shop": true, "long": true}],
	["Potato", "pf", 0, "root", "c79a5a", "", {"shop": true}],
	["Radish", "p", 0, "root", "e8455a", "", {"shop": true}],
	["Beet", "f", 0, "root", "8a1f4a", "", {"shop": true}],
	["Onion", "pf", 0, "root", "e6c27a", "", {"shop": true}],
	["Garlic", "p", 0, "root", "f0eadc", "", {"shop": true}],
	["Parsnip", "p", 0, "root", "efe2b0", "", {"shop": true, "long": true}],
	["Sweet Potato", "f", 1, "root", "c0563a", "", {"shop": true, "long": true}],
	["Yam", "f", 1, "root", "8a4a7a", "", {"long": true}],
	["Winter Radish", "w", 1, "root", "f4f4ff", "", {"shop": true}],
	["Lettuce", "ps", 0, "leafy", "9fdc6a", "", {"shop": true}],
	["Cabbage", "pf", 0, "leafy", "bfe39a", "", {"shop": true}],
	["Spinach", "pf", 0, "leafy", "3f9f3a", "", {"shop": true}],
	["Kale", "fw", 1, "leafy", "3a7a52", "", {"shop": true}],
	["Broccoli", "f", 1, "leafy", "4f8f3a", "", {"shop": true}],
	["Cauliflower", "p", 1, "leafy", "f4f2e0", "", {}],
	["Rhubarb", "p", 0, "leafy", "d0405a", "", {"shop": true}],
	["Artichoke", "s", 2, "leafy", "8fb07a", "", {}],
	["Pea", "p", 0, "vine", "8fd65a", "", {"shop": true, "pod": true}],
	["Green Bean", "s", 0, "vine", "5fae3a", "", {"shop": true, "pod": true}],
	["Snow Pea", "w", 1, "vine", "c8eea8", "", {"shop": true, "pod": true}],
	["Tomato", "s", 0, "vine", "e8442e", "", {"shop": true}],
	["Hot Pepper", "s", 1, "vine", "e8331f", "", {"shop": true, "pod": true}],
	["Eggplant", "s", 1, "vine", "6a3a8a", "", {"shop": true, "pod": true}],
	["Cucumber", "s", 0, "vine", "3f8f2f", "", {"shop": true, "pod": true}],
	["Zucchini", "s", 0, "gourd", "4f8f3a", "", {"shop": true}],
	["Pumpkin", "f", 1, "gourd", "f08a1a", "", {"shop": true}],
	["Melon", "s", 1, "gourd", "8fcf5a", "", {"shop": true}],
	["Squash", "f", 0, "gourd", "f2c23a", "", {"shop": true}],
	["Corn", "s", 0, "tall", "f2d23a", "f0e8a0", {"shop": true, "shape": "corn"}],
	["Wheat", "sf", 0, "grain", "e8c86a", "", {"shop": true}],
	["Rice", "s", 1, "grain", "f2ecd0", "", {}],
	["Leek", "w", 0, "grain", "bfe0a0", "", {"shop": true}],
	["Strawberry", "p", 1, "bush", "e83a4a", "", {"shop": true, "small": true}],
	["Cranberry", "f", 1, "bush", "b0203a", "", {"small": true}],
	["Celery", "s", 0, "grain", "9fd88a", "", {"shop": true}],
]

const FLOWERS := [
	["Tulip", "p", 0, "flower", "e8455a", "f2d23a", {"shop": true, "shape": "cup"}],
	["Daisy", "ps", 0, "flower", "ffffff", "f2c23a", {"shop": true, "shape": "daisy"}],
	["Sunflower", "s", 0, "tall", "f2c21a", "6a3a1a", {"shop": true, "shape": "sun"}],
	["Poppy", "ps", 0, "flower", "e83a2a", "3a1a1a", {"shop": true, "shape": "round"}],
	["Rose", "ps", 1, "flower", "d0203a", "", {"shape": "rose"}],
	["Lily", "s", 1, "flower", "fff0f5", "f0a0c0", {"shape": "star"}],
	["Orchid", "s", 2, "flower", "d080e0", "fff0ff", {"shape": "star"}],
	["Daffodil", "p", 0, "flower", "f2e23a", "f29a1a", {"shape": "cup", "shop": true}],
	["Marigold", "sf", 0, "flower", "f29a1a", "c05a1a", {"shape": "dense", "shop": true}],
	["Violet", "p", 0, "flower", "7a4ad0", "f2e23a", {"shape": "round"}],
	["Peony", "p", 2, "flower", "f2a0c4", "", {"shape": "rose"}],
	["Iris", "p", 1, "flower", "5a5ae0", "f2e23a", {"shape": "star"}],
	["Hyacinth", "p", 1, "flower", "9a6ae0", "", {"shape": "spike"}],
	["Carnation", "ps", 1, "flower", "f06a8a", "", {"shape": "dense"}],
	["Dahlia", "f", 2, "flower", "c03a6a", "", {"shape": "dense"}],
	["Chrysanthemum", "f", 1, "flower", "f2c23a", "", {"shape": "dense"}],
	["Cosmos", "sf", 0, "flower", "f080b0", "f2e23a", {"shape": "daisy"}],
	["Zinnia", "s", 0, "flower", "f05a3a", "f2e23a", {"shape": "daisy"}],
	["Pansy", "pf", 0, "flower", "6a4ab0", "f2e23a", {"shape": "round"}],
	["Snapdragon", "s", 1, "flower", "f06a6a", "", {"shape": "spike"}],
	["Bluebell", "p", 1, "flower", "5a7ae0", "", {"shape": "bell"}],
	["Camellia", "w", 2, "flower", "e03a5a", "", {"shape": "rose"}],
	["Lotus", "s", 2, "flower", "f0b0d0", "f2e23a", {"shape": "star"}],
	["Hibiscus", "s", 1, "flower", "e8334a", "f2e23a", {"shape": "star"}],
	["Aster", "f", 0, "flower", "9a7ae0", "f2e23a", {"shape": "daisy"}],
	["Gardenia", "s", 2, "flower", "fffaf0", "", {"shape": "rose"}],
	["Foxglove", "s", 1, "flower", "c07ad0", "", {"shape": "bell"}],
	["Cornflower", "s", 0, "flower", "3a6ae0", "", {"shape": "star"}],
	["Larkspur", "s", 1, "flower", "5a5ad0", "", {"shape": "spike"}],
	["Morning Glory", "s", 1, "flower", "4a7ae0", "ffffff", {"shape": "cup"}],
	["Anemone", "f", 1, "flower", "e04a6a", "2a2a3a", {"shape": "round"}],
	["Primrose", "p", 0, "flower", "f2e27a", "f29a1a", {"shape": "round"}],
	["Snowdrop", "w", 1, "flower", "f8f8ff", "8fd06a", {"shape": "bell"}],
	["Hellebore", "w", 2, "flower", "c090c0", "f2e27a", {"shape": "round"}],
	["Poinsettia", "w", 1, "flower", "d0202a", "f2e23a", {"shape": "star"}],
	["Crocus", "pw", 0, "flower", "a07ae0", "f29a1a", {"shape": "cup"}],
	["Freesia", "p", 1, "flower", "f2d0e0", "", {"shape": "bell"}],
	["Edelweiss", "s", 2, "flower", "f8f8f0", "f2e27a", {"shape": "star", "region": "mountains"}],
	["Gentian", "f", 1, "flower", "3a4ad0", "", {"shape": "bell", "region": "mountains"}],
	["Alpine Rose", "s", 1, "flower", "e05a8a", "", {"shape": "rose", "region": "mountains"}],
	["Bleeding Heart", "p", 1, "flower", "e05a7a", "ffffff", {"shape": "bell", "region": "forest"}],
	["Trillium", "p", 1, "flower", "ffffff", "f2e27a", {"shape": "star", "region": "forest"}],
]

const HERBS := [
	["Basil", "s", 0, "herb", "4fae3a", "ffffff", {"shop": true}],
	["Mint", "ps", 0, "herb", "6fd08a", "c8a0f0", {"shop": true}],
	["Rosemary", "pw", 0, "herb", "4f7f5a", "8fb0f0", {"shop": true}],
	["Thyme", "ps", 0, "herb", "6f9f4a", "f0b0e0", {"shop": true}],
	["Sage", "sf", 0, "herb", "8fae8a", "a080e0", {"shop": true}],
	["Parsley", "pf", 0, "herb", "3f9f3a", "f2f0a0", {"shop": true}],
	["Cilantro", "p", 0, "herb", "5fbf4a", "ffffff", {"shop": true}],
	["Dill", "s", 0, "herb", "7fbf5a", "f2e23a", {"shop": true}],
	["Chamomile", "p", 1, "herb", "6faf4a", "ffffff", {}],
	["Lavender", "s", 1, "herb", "6f8f6a", "9a6ae0", {}],
	["Oregano", "s", 0, "herb", "5f9f4a", "e0a0e0", {"shop": true}],
	["Lemongrass", "s", 1, "herb", "a0d06a", "f2f0a0", {}],
	["Chives", "pf", 0, "herb", "4fbf4a", "c080e0", {"shop": true}],
	["Fennel", "f", 1, "herb", "8fcf7a", "f2e23a", {}],
	["Tarragon", "s", 1, "herb", "5f8f4a", "e8e0a0", {}],
	["Catnip", "ps", 1, "herb", "7fbf8a", "f0f0ff", {}],
	["Mountain Sage", "s", 2, "herb", "8fa0a0", "7a8af0", {"region": "mountains"}],
	["Wintergreen", "w", 1, "herb", "2f6f4a", "e83a4a", {}],
]

const BUSHES := [
	["Blueberry", "s", 1, "bush", "4a5ad0", "", {}],
	["Raspberry", "s", 1, "bush", "e0305a", "", {}],
	["Blackberry", "f", 1, "bush", "3a2050", "", {}],
	["Gooseberry", "s", 1, "bush", "a8d070", "", {}],
	["Holly", "w", 1, "bush", "e0202a", "", {}],
	["Hydrangea", "s", 2, "bush", "8a9af0", "", {"shape": "flowers"}],
	["Azalea", "p", 1, "bush", "f06aa0", "", {"shape": "flowers"}],
	["Elderberry", "f", 2, "bush", "4a2a5a", "", {}],
	["Tea Leaf", "p", 2, "bush", "5f9f4a", "", {"shape": "tea"}],
	["Huckleberry", "s", 2, "bush", "6a3a9a", "", {"region": "mountains"}],
]

const TREES := [
	["Apple", "f", 1, "tree", "e8342e", "", {"shop": true}],
	["Cherry", "p", 1, "tree", "c8102e", "", {}],
	["Peach", "s", 1, "tree", "f8a070", "", {}],
	["Orange", "s", 1, "tree", "f2902a", "", {}],
	["Lemon", "s", 1, "tree", "f2e23a", "", {}],
	["Pear", "f", 1, "tree", "c8d050", "", {}],
	["Plum", "s", 1, "tree", "7a2a7a", "", {}],
	["Fig", "s", 2, "tree", "6a3a5a", "", {}],
	["Pomegranate", "f", 2, "tree", "b8202a", "", {}],
	["Apricot", "s", 1, "tree", "f8b050", "", {}],
	["Olive", "f", 2, "tree", "6a7a2a", "", {}],
	["Persimmon", "f", 2, "tree", "f07020", "", {}],
	["Lime", "s", 1, "tree", "8fd03a", "", {}],
	["Avocado", "s", 2, "tree", "3a5a2a", "", {}],
	["Mango", "s", 2, "tree", "f8b030", "", {"region": "ancient_ruins"}],
]

const MUSHROOMS := [
	["Button Mushroom", "*", 0, "mushroom", "efe4d2", "c8b8a0", {}],
	["Shiitake", "*", 0, "mushroom", "8a5a3a", "efe4d2", {}],
	["Oyster Mushroom", "*", 0, "mushroom", "c8c0b8", "a8a0a0", {"cluster": true}],
	["Chanterelle", "*", 1, "mushroom", "f2a83a", "f2c85a", {}],
	["Morel", "p", 1, "mushroom", "a08050", "6a4a2a", {"spots": true}],
	["Porcini", "f", 1, "mushroom", "8a4a2a", "efe4d2", {}],
	["Enoki", "*", 0, "mushroom", "f8f4e8", "e8e0c8", {"cluster": true}],
	["Black Truffle", "*", 3, "mushroom", "2a2228", "5a4a50", {"shape": "truffle"}],
	["Fly Agaric", "*", 1, "mushroom", "e0201a", "ffffff", {"spots": true}],
	["Glowcap", "*", 2, "mushroom", "5ae0d0", "c8fff4", {"glow": true, "spots": true}],
	["Puffball", "*", 0, "mushroom", "f4f0e8", "d8d0c0", {"shape": "puff"}],
	["Inkcap", "*", 1, "mushroom", "3a3a4a", "8a8aa0", {"cluster": true}],
	["Lion's Mane", "*", 2, "mushroom", "f8f0d8", "e8d8b0", {"shape": "puff"}],
	["Moonshroom", "*", 3, "mushroom", "b0c0ff", "ffffff", {"glow": true, "spots": true}],
	["Blue Mycena", "*", 2, "mushroom", "4a7af0", "a0c0ff", {"cluster": true, "glow": true}],
	["Coral Fungus", "*", 1, "mushroom", "f07a8a", "f8b0b8", {"shape": "coral"}],
]

const EXOTIC := [
	["Venus Flytrap", "s", 2, "exotic", "d03a3a", "8fd03a", {"shape": "trap"}],
	["Pitcher Plant", "s", 2, "exotic", "8a3a5a", "c8e070", {"shape": "pitcher"}],
	["Bird of Paradise", "s", 2, "exotic", "f2902a", "4a6ae0", {"shape": "palm", "fruit": "flower"}],
	["Dragon Fruit", "s", 2, "exotic", "f04a8a", "8fd03a", {"shape": "cactus"}],
	["Aloe Vera", "*", 1, "exotic", "7fbf8a", "f29a3a", {"shape": "aloe"}],
	["Cactus Bloom", "s", 1, "exotic", "f0609a", "f2e23a", {"shape": "cactus"}],
	["Bamboo", "*", 1, "exotic", "8fcf5a", "", {"shape": "bamboo"}],
	["Coffee Bean", "s", 2, "exotic", "c03a2a", "", {"shape": "palm"}],
	["Cacao Pod", "s", 2, "exotic", "c8762a", "", {"shape": "palm"}],
	["Vanilla Orchid", "s", 3, "exotic", "f8f0c8", "f2d23a", {"shape": "palm", "fruit": "flower"}],
	["Pineapple", "s", 2, "exotic", "f2c23a", "6faf4a", {"shape": "pineapple"}],
	["Passionflower", "s", 2, "exotic", "9a6ae0", "ffffff", {"shape": "palm", "fruit": "flower"}],
	["Corpse Lily", "s", 3, "exotic", "a0202a", "f2e8d0", {"shape": "titan"}],
	["Starfruit", "s", 2, "exotic", "f2e04a", "", {"shape": "palm"}],
	["Monstera", "*", 1, "exotic", "2f8f4a", "", {"shape": "palm", "fruit": "none"}],
	["Kiwano", "s", 2, "exotic", "f2902a", "", {"shape": "cactus"}],
]

const MYTHICAL := [
	["Moonpetal", "*", 2, "mythic", "c8d8ff", "ffffff", {"shape": "star", "lore": "Moonpetals open only under moonlight, storing a little of it in every petal."}],
	["Sunbloom", "*", 2, "mythic", "ffd83a", "ff8a2a", {"shape": "sun", "lore": "Warm to the touch, even in the dead of winter. Fairies nap inside its petals."}],
	["Starflower", "*", 2, "mythic", "fff08a", "ffffff", {"shape": "star", "lore": "Said to sprout wherever a falling star lands. Its pollen glitters like dust."}],
	["Phoenix Fern", "*", 3, "mythic", "ff6a2a", "ffd83a", {"shape": "fern", "lore": "When it withers, it bursts into harmless flame and grows anew from the ashes."}],
	["Dragonsnap", "*", 3, "mythic", "3ad08a", "f2e23a", {"shape": "spike", "lore": "A snapdragon that actually snaps. Keep fingers clear when it yawns."}],
	["Fairy Bell", "*", 2, "mythic", "f0a0ff", "ffffff", {"shape": "bell", "lore": "Each bell chimes a different note. A full bed plays a lullaby on windy nights."}],
	["Wishweed", "*", 2, "mythic", "e8f0ff", "c8a0ff", {"shape": "daisy", "lore": "Blow on its seed-head and make a wish. Results not guaranteed, but often delightful."}],
	["Spirit Lotus", "*", 3, "mythic", "a0f0ff", "ffffff", {"shape": "star", "lore": "Monks once meditated beside it for a hundred days to hear it whisper a single word."}],
	["Frost Lily", "*", 2, "mythic", "a0e0ff", "e8f8ff", {"shape": "cup", "lore": "Its petals are made of living ice that never melts and never chills the hand."}],
	["Ember Rose", "*", 3, "mythic", "ff4a2a", "ffb03a", {"shape": "rose", "lore": "Glows like a coal in a hearth. Travelers use it as a lantern on long roads."}],
	["Void Orchid", "*", 3, "mythic", "3a1a6a", "c88aff", {"shape": "star", "lore": "Looking into its center feels like looking into a starry night sky."}],
	["Cloud Cotton", "*", 2, "mythic", "ffffff", "c8e0ff", {"shape": "puffs", "lore": "Fluffy bolls that float a little off the stem. Pillows stuffed with it cure nightmares."}],
	["Mandrake", "*", 3, "mythic", "c8a070", "6faf4a", {"shape": "mandrake", "lore": "Harvest gently and hum a tune: mandrakes only scream when startled."}],
	["World Tree Sprout", "*", 4, "mythic", "8fffb0", "ffe08a", {"shape": "worldtree", "lore": "A sapling of the great tree said to hold up the sky. Every garden dreams of one."}],
]

const CRYSTALS := [
	["Amethyst Sprout", "*", 2, "crystal", "a06ae0", "e0c8ff", {"shape": "shard", "lore": "Grows a new facet every night. Hold it to your ear to hear faint chimes."}],
	["Quartz Rose", "*", 2, "crystal", "f0d0e0", "ffffff", {"shape": "rose", "lore": "A rose of pure rose quartz. Its thorns are gentle and perfectly smooth."}],
	["Sapphire Bell", "*", 2, "crystal", "3a6af0", "a0c8ff", {"shape": "bell", "lore": "Rings with a clear blue tone when the wind passes through Crystal Hollow."}],
	["Emerald Vine", "*", 3, "crystal", "2ad07a", "a0ffc8", {"shape": "spike", "lore": "Each leaf is a tiny gem. Gem-cutters will trade almost anything for a cutting."}],
	["Ruby Tulip", "*", 3, "crystal", "e01a3a", "ffa0b0", {"shape": "cup", "lore": "A tulip-shaped ruby that seems to glow from within like a heart."}],
	["Topaz Lily", "*", 2, "crystal", "f2a82a", "fff0a0", {"shape": "star", "lore": "Turns sunlight into warm amber light that lingers long after dusk."}],
	["Opal Orchid", "*", 3, "crystal", "e0f0ff", "ffb0e0", {"shape": "star", "lore": "Shows a different color to every person who looks at it."}],
	["Diamond Daisy", "*", 3, "crystal", "f0ffff", "c8f0ff", {"shape": "daisy", "lore": "Harder than steel yet sways in the breeze. Nobody knows how."}],
	["Obsidian Thorn", "*", 3, "crystal", "2a1a3a", "8a6aaa", {"shape": "shard", "lore": "Formed in the deepest cave fires. Glassy, dark and strangely calming."}],
	["Prism Blossom", "*", 4, "crystal", "ffffff", "ff8ac8", {"shape": "prism", "lore": "Splits light into rainbows across the garden. The rarest jewel of Crystal Hollow."}],
]

const ANCIENT := [
	["Ancient Fern", "*", 2, "fern", "6a8a3a", "", {"lore": "This fern looked exactly the same when dinosaurs walked the earth."}],
	["Amber Cycad", "*", 2, "fern", "5a7a3a", "e8a030", {"shape": "cone", "lore": "Its cones weep amber. Some still hold tiny ancient insects inside."}],
	["Fossil Flower", "*", 3, "flower", "d8c8a8", "8a7a6a", {"shape": "round", "lore": "Grown from a seed found pressed in stone. Its petals feel like warm sandstone."}],
	["Petrified Bloom", "*", 3, "flower", "a8a0a0", "e0d0b0", {"shape": "star", "lore": "Half stone, half flower, entirely mysterious. It blooms once a century... or once a week here."}],
	["Ancestor Oak", "*", 3, "tree", "5a7a3a", "c8a050", {"shape": "oak", "lore": "Carvings on the ruins show people dancing around this exact tree."}],
	["Runeleaf", "*", 3, "herb", "3a6a5a", "5af0f0", {"lore": "Glowing runes appear on its leaves. Scholars are still arguing about what they say."}],
	["Titan Arum", "*", 3, "exotic", "6a1a4a", "e8d870", {"shape": "titan", "lore": "A towering bloom that only the bravest noses dare to sniff."}],
	["Primordial Moss", "*", 2, "fern", "4a8a4a", "a0e070", {"shape": "moss", "lore": "Possibly the first plant ever. It seems unimpressed by everything since."}],
	["Silphium", "*", 4, "flower", "f2e04a", "8fbf4a", {"shape": "umbel", "lore": "A legendary herb lost to history, prized above gold by ancient kingdoms."}],
]

const SEASONAL := [
	["Sakura Blossom", "p", 3, "tree", "f8b8d0", "", {"shape": "sakura", "lore": "Given out at the Spring Blossom Festival. Its petals drift down like pink snow."}],
	["Heartbloom", "p", 3, "flower", "f04a7a", "ffd0e0", {"shape": "round", "lore": "Shared between friends at the Spring Festival. Its petals are shaped like hearts."}],
	["Solstice Sunflower", "s", 3, "tall", "ffb01a", "a02a1a", {"shape": "sun", "lore": "Only blooms on the longest days. Follows the sun even after sunset."}],
	["Lantern Flower", "s", 3, "flower", "ff9a3a", "fff0a0", {"shape": "bell", "lore": "Floats glowing lanterns at the Summer Lantern Festival."}],
	["Harvest Moon Pumpkin", "f", 3, "gourd", "e8681a", "", {"lore": "The prize gourd of the Harvest Moon Festival. Glows faintly orange at night."}],
	["Spooky Gourd", "f", 3, "gourd", "6a3a9a", "", {"lore": "Carves itself a little smile when nobody is watching."}],
	["Starlight Poinsettia", "w", 3, "flower", "f0f0ff", "ffe04a", {"shape": "star", "lore": "Gifted at the Winter Star Festival. Twinkles like a tiny constellation."}],
	["Snow Bloom", "w", 3, "flower", "e8f8ff", "a0d8ff", {"shape": "daisy", "lore": "Grows only where snow falls on festival night. Never melts in your hand."}],
]

## Festival day of each season and the event plants it offers.
const FESTIVAL_DAY := 7
const FESTIVAL_NAMES := ["Spring Blossom Festival", "Summer Lantern Festival", "Harvest Moon Festival", "Winter Star Festival"]
const FESTIVAL_PLANTS := [["sakura_blossom", "heartbloom"], ["solstice_sunflower", "lantern_flower"], ["harvest_moon_pumpkin", "spooky_gourd"], ["starlight_poinsettia", "snow_bloom"]]

# ---------------------------------------------------------------- TOOLS
const TOOL_ORDER := ["watering_can", "shovel", "seed_pouch", "collection_bag", "spreader", "sickle"]
const TOOL_TIERS := ["Wooden", "Copper", "Silver", "Golden", "Enchanted"]
const TOOL_TIER_COLORS := [Color("a0743a"), Color("d8823a"), Color("c8d0dc"), Color("f2c23a"), Color("b67aff")]
const TOOL_COSTS := [0, 500, 1800, 5000, 14000]
const TOOL_LEVEL_REQ := [1, 2, 4, 7, 10]
const TOOL_DEFS := {
	"watering_can": {"name": "Watering Can", "desc": "Holds more water and soaks more soil per pour."},
	"shovel": {"name": "Shovel", "desc": "Tills more soil per swing and digs up buried relics (Silver+)."},
	"seed_pouch": {"name": "Seed Pouch", "desc": "Plants more seeds at once, with a chance to save seeds."},
	"collection_bag": {"name": "Collection Bag", "desc": "Finds extra loot when foraging and improves rare finds."},
	"spreader": {"name": "Fertilizer Spreader", "desc": "Spreads fertilizer over a wider area with stronger effects."},
	"sickle": {"name": "Harvest Sickle", "desc": "Harvests more plants per swing, boosts yield and mutation odds."},
}
const WATER_CAPACITY := [15, 30, 50, 80, 150]

# ---------------------------------------------------------------- FERTILIZERS
const FERTILIZERS := [
	["compost", "Basic Compost", 0, 20, "9a6a3a", "25% chance a plant grows an extra day overnight."],
	["quality_fertilizer", "Quality Fertilizer", 1, 45, "5aa04a", "+1 bonus harvest yield."],
	["speed_gro", "Speed-Gro", 1, 70, "3a8ad0", "Plants grow twice as fast."],
	["magic_mulch", "Magic Mulch", 2, 120, "c06ae0", "Triples the chance of Golden & Rainbow mutations."],
	["starlight_fertilizer", "Starlight Fertilizer", 2, 150, "f2e8a0", "Required to grow Mythical plants."],
	["crystal_dust", "Crystal Dust", 2, 180, "a0d0ff", "Required to grow Crystal plants."],
	["ancient_compost", "Ancient Compost", 3, 260, "6a5a3a", "Required to grow Ancient plants."],
]

# ---------------------------------------------------------------- DECOR
## [id, name, price, rarity, kind, color1, color2, flags, description]
## flags: "solid", "floor", "light"
const DECOR := [
	["bench_wood", "Wooden Bench", 180, 0, "bench", "a0683a", "", "solid", "A sturdy bench for watching your garden grow."],
	["bench_stone", "Stone Bench", 320, 1, "stone_bench", "b8b8b0", "", "solid", "Cool on a hot summer day."],
	["picnic_table", "Picnic Table", 450, 1, "table", "b0783a", "e85a5a", "solid", "Checkered cloth included, ants not included."],
	["garden_chair", "Garden Chair", 150, 0, "chair", "f0f0e8", "", "solid", "A crisp white chair for afternoon tea."],
	["birdbath", "Birdbath", 380, 1, "birdbath", "c8c8c0", "6ab0f0", "solid", "Birds gossip here every morning."],
	["fountain_small", "Little Fountain", 900, 2, "fountain", "b8b8c8", "6ab0f0", "solid", "The gentle trickle makes plants feel calm."],
	["fountain_grand", "Grand Fountain", 3500, 3, "fountain_big", "e8e0d0", "5aa8f0", "solid", "The centerpiece of any legendary garden."],
	["gnome", "Garden Gnome", 220, 0, "gnome", "e03a3a", "3a6ae0", "solid", "He guards your carrots with his life."],
	["angel_statue", "Angel Statue", 1200, 2, "statue_angel", "e8e8e0", "", "solid", "Watches over the garden with a serene smile."],
	["fox_statue", "Fox Statue", 650, 1, "statue_fox", "e0803a", "ffffff", "solid", "A clever fox carved from warm stone."],
	["owl_statue", "Owl Statue", 650, 1, "statue_owl", "a08a6a", "f2d23a", "solid", "Keeps an eye out for slugs at night."],
	["frog_statue", "Frog Statue", 400, 1, "statue_frog", "6ab04a", "f2e23a", "solid", "Ribbit."],
	["stone_lantern", "Stone Lantern", 500, 1, "lantern", "a8a8a0", "ffd86a", "solid,light", "Glows warmly after sunset."],
	["lamp_post", "Lamp Post", 600, 1, "lamp", "3a3a4a", "ffe08a", "solid,light", "Lights the garden paths at night."],
	["flower_arch", "Flower Arch", 950, 2, "arch", "f0f0e8", "f06a9a", "", "Walk through it to feel like royalty."],
	["trellis", "Rose Trellis", 420, 1, "trellis", "c8a070", "e03a5a", "solid", "Climbing roses love a good trellis."],
	["fence_wood", "Wooden Fence", 40, 0, "fence", "a0683a", "", "solid", "Keeps the rabbits honest."],
	["fence_white", "Picket Fence", 60, 0, "picket", "f4f4ec", "", "solid", "The classic white picket fence."],
	["path_stone", "Stone Path", 25, 0, "path_stone", "a8a8a0", "", "floor", "Cobbled stones for tidy feet."],
	["path_brick", "Brick Path", 35, 0, "path_brick", "c0603a", "", "floor", "Warm red bricks in a herringbone pattern."],
	["stepping_stones", "Stepping Stones", 30, 0, "stepping", "b8b8b0", "", "floor", "Hop, skip, garden."],
	["pot_clay", "Clay Pot", 60, 0, "pot", "c06a3a", "4fae3a", "solid", "A simple pot with a happy little sprout."],
	["pot_blue", "Glazed Blue Pot", 180, 1, "pot", "3a6ac0", "f06a9a", "solid", "Hand-glazed by the village potter."],
	["pot_golden", "Golden Pot", 2500, 3, "pot", "f2c23a", "c06ae0", "solid", "Only for the most pampered of plants."],
	["hanging_planter", "Hanging Planter", 260, 1, "hanging", "a0683a", "f0a03a", "solid", "Flowers cascading from above."],
	["windmill", "Windmill", 1800, 2, "windmill", "e8d8b8", "c0503a", "solid", "Spins lazily in the breeze."],
	["scarecrow", "Scarecrow", 300, 0, "scarecrow", "e0c060", "3a6ac0", "solid", "Friendly to everyone except crows."],
	["beehive", "Beehive", 700, 1, "beehive", "f2c23a", "a0683a", "solid", "Happy bees make for happy flowers."],
	["birdhouse", "Birdhouse", 350, 1, "birdhouse", "c0603a", "f0e8d0", "solid", "Prime real estate for songbirds."],
	["wheelbarrow", "Wheelbarrow", 280, 0, "wheelbarrow", "c03a3a", "8a5a3a", "solid", "Full of soil and good intentions."],
	["sundial", "Sundial", 800, 2, "sundial", "c8c0b0", "f2c23a", "solid", "Tells time beautifully, on sunny days."],
	["wishing_well", "Wishing Well", 1500, 2, "wishing_well", "a8a8a0", "a0683a", "solid", "Toss in a coin and wish for rare seeds."],
	["mushroom_lamp", "Mushroom Lamp", 900, 2, "mushroom_lamp", "e03a5a", "fff0c0", "solid,light", "A glowing toadstool from the caves."],
	["crystal_lamp", "Crystal Lamp", 1600, 3, "crystal_lamp", "a06ae0", "e0c8ff", "solid,light", "Hums softly with crystal light."],
	["fairy_lights", "Fairy Lights", 1100, 2, "fairy_lights", "6a4a2a", "fff08a", "solid,light", "Tiny lights that dance like fireflies."],
	["trophy_bronze", "Bronze Collector Trophy", 0, 1, "trophy", "c8823a", "", "solid", "Awarded for discovering 25 collectibles."],
	["trophy_silver", "Silver Collector Trophy", 0, 2, "trophy", "d0d8e0", "", "solid", "Awarded for discovering 75 collectibles."],
	["trophy_gold", "Gold Collector Trophy", 0, 3, "trophy", "f2c23a", "", "solid", "Awarded for discovering 150 collectibles."],
	["trophy_platinum", "Platinum Collector Trophy", 0, 3, "trophy", "e8f8ff", "", "solid", "Awarded for discovering 250 collectibles."],
	["trophy_rainbow", "Rainbow Collector Trophy", 0, 4, "trophy", "ff6ab0", "", "solid", "Awarded for discovering 350 collectibles. A true master gardener!"],
	["gardener_statue", "Master Gardener Statue", 0, 4, "statue_gardener", "f2c23a", "", "solid", "Awarded for completing an entire Collection Book category."],
]

# ---------------------------------------------------------------- TREASURES
## [id, name, rarity, kind, color, regions(comma list), description]
const TREASURES := [
	["smooth_pebble", "Smooth Pebble", 0, "pebble", "a8a8b0", "home,village,flower_fields,forest", "Perfectly round. Great for skipping across ponds."],
	["bluejay_feather", "Bluejay Feather", 0, "feather", "4a7ae0", "forest,home", "A bright blue feather dropped by a passing jay."],
	["pinecone", "Pinecone", 0, "cone", "8a5a32", "forest,mountains", "Squirrels hoard these by the dozen."],
	["acorn", "Golden Acorn", 1, "acorn", "e0a83a", "forest", "A rare acorn with a shiny golden cap."],
	["four_leaf_clover", "Four-Leaf Clover", 1, "clover", "4fbf4a", "flower_fields,home", "Lucky! Gardeners say it brings mutations."],
	["butterfly_wing", "Butterfly Wing", 1, "wing", "f29a3a", "flower_fields,fairy_garden", "Shed naturally and carefully saved."],
	["honeycomb", "Wild Honeycomb", 1, "comb", "f2c23a", "flower_fields,forest", "Sweet golden honey from wild bees."],
	["snail_shell", "Spiral Shell", 0, "shell", "e0c0a0", "home,forest,mushroom_caves", "An empty snail shell with a perfect spiral."],
	["glow_moss", "Glow Moss", 1, "moss", "5af0b0", "mushroom_caves", "Softly luminous moss from deep caves."],
	["dewdrop_pearl", "Dewdrop Pearl", 2, "pearl", "e0f0ff", "fairy_garden,flower_fields", "Morning dew that hardened into a pearl."],
	["mountain_ore", "Mountain Ore", 0, "ore", "8a7a6a", "mountains,mushroom_caves", "A chunk of ore glittering with minerals."],
	["geode", "Geode", 1, "geode", "8a6ac0", "mountains,crystal_biome", "Crack it open to find crystals inside."],
	["quartz_chunk", "Quartz Chunk", 1, "gem", "f0f0ff", "mountains,crystal_biome", "Clear as frozen water."],
	["amethyst_shard", "Amethyst Shard", 2, "gem", "a06ae0", "crystal_biome", "A sliver of purple crystal humming faintly."],
	["amber", "Amber", 2, "pearl", "e8a030", "ancient_ruins,forest", "Fossilized tree resin, warm and golden."],
	["fairy_dust", "Fairy Dust", 2, "dust", "f8b0f0", "fairy_garden", "Sparkly dust that makes everything feel lighter."],
	["pixie_wing", "Pixie Wing", 3, "wing", "a0f0ff", "fairy_garden", "Gossamer-thin and shimmering with color."],
	["starlight_shard", "Starlight Shard", 3, "gem", "fff08a", "fairy_garden,crystal_biome", "A fragment of fallen starlight."],
	["moon_pearl", "Moon Pearl", 3, "pearl", "c8d0ff", "crystal_biome,fairy_garden", "Glows brighter on nights with a full moon."],
	["ancient_coin", "Ancient Coin", 1, "coin", "e0b03a", "ancient_ruins", "Stamped with the face of a forgotten queen."],
	["clay_tablet", "Clay Tablet", 2, "tablet", "c08a5a", "ancient_ruins", "Carved with drawings of old gardens."],
	["fossil_leaf", "Fossil Leaf", 2, "fossil", "b0a080", "ancient_ruins,mountains", "A leaf from millions of years ago, preserved in stone."],
	["old_map", "Old Map Fragment", 2, "map", "e0d0a0", "ancient_ruins", "Part of a map marked with tiny flower symbols."],
	["golden_idol", "Golden Idol", 4, "idol", "f2c23a", "ancient_ruins", "A priceless relic of the ancient garden-keepers."],
]

## Lore templates for generic categories ({n} = name)
const LORE := {
	"crop": [
		"A dependable %s. Grandma Wren swore the secret was talking to it every morning.",
		"Village cooks pay well for a crisp %s, especially fresh from the soil.",
		"Every gardener remembers their first %s harvest. It always tastes the best.",
		"Legend says a %s once won the Willowbrook Fair through sheer stubbornness.",
		"Plant it, water it, love it. The humble %s asks for little and gives plenty.",
	],
	"flower": [
		"Bees line up politely for a turn at a fresh %s.",
		"Pressed %s petals are tucked into letters between old friends.",
		"A bouquet of %s is the traditional way to say 'welcome home'.",
		"Painters travel far just to capture the color of a %s at dawn.",
		"The %s sways even on windless days, as if listening to music.",
	],
	"herb": [
		"A pinch of %s makes any stew taste like a warm afternoon.",
		"Brushing past %s leaves a scent that lingers for hours.",
		"Village healers keep bundles of dried %s hanging by the window.",
		"Cats, bees and grandmothers all agree: %s is wonderful.",
	],
	"bush": [
		"Birds keep a careful eye on any %s bush close to fruiting.",
		"A well-tended %s bush feeds a family through the whole season.",
		"Hedgehogs love napping beneath a leafy %s bush.",
	],
	"tree": [
		"A %s tree planted today will shade your grandchildren's picnics.",
		"Climbing a %s tree is a rite of passage for every village child.",
		"The first %s of the season is always shared with a neighbor.",
	],
	"mushroom": [
		"%s pop up overnight, as though they had been there all along.",
		"Cave keepers say %s hum softly when no one is listening.",
		"Never eat a mushroom you can't name. Luckily, this one is %s.",
	],
	"exotic": [
		"Brought back by an explorer who swore never to reveal where the %s came from.",
		"The %s prefers warmth, patience and a little bit of drama.",
		"Visitors gasp when they see a %s growing in an ordinary garden.",
	],
}

var items: Dictionary = {}
var order: Array = []
var plant_ids: Array = []
var flower_ids: Array = []


func _ready() -> void:
	_build()


# ================================================================= BUILD
func _build() -> void:
	_add_plants("crop", "home", CROPS)
	_add_plants("flower", "flower_fields", FLOWERS)
	_add_plants("herb", "forest", HERBS)
	_add_plants("bush", "forest", BUSHES)
	_add_plants("tree", "forest", TREES)
	_add_plants("mushroom", "mushroom_caves", MUSHROOMS)
	_add_plants("exotic", "ancient_ruins", EXOTIC)
	_add_plants("mythical", "fairy_garden", MYTHICAL)
	_add_plants("crystal", "crystal_biome", CRYSTALS)
	_add_plants("ancient", "ancient_ruins", ANCIENT)
	_add_plants("seasonal", "festival", SEASONAL)
	_add_mutations()
	_add_tools()
	_add_decor()
	_add_treasures()


func slug(n: String) -> String:
	var s := n.to_lower().replace("'", "").replace("-", "_").replace(" ", "_")
	return s


func _parse_seasons(s: String) -> Array:
	if s == "*":
		return [0, 1, 2, 3]
	var out := []
	for ch in s:
		var i := "psfw".find(ch)
		if i >= 0:
			out.append(i)
	return out


func _round5(v: float) -> int:
	return int(round(v / 5.0) * 5)


func _add(id: String, d: Dictionary) -> void:
	d["id"] = id
	items[id] = d
	order.append(id)


func _add_plants(cat: String, region: String, rows: Array) -> void:
	for row in rows:
		var name: String = row[0]
		var opts: Dictionary = row[6] if row.size() > 6 else {}
		var rarity: int = row[2]
		var arch: String = row[3]
		var c1 := Color(row[4])
		var c2: Color = Color(row[5]) if String(row[5]) != "" else c1.lightened(0.35)
		var id := slug(name)
		var days: int = BASE_DAYS[rarity]
		match arch:
			"tree": days += 4
			"gourd", "bush": days += 1
			"grain": days = max(2, days - 1)
		days = opts.get("days", days)
		var regrow := 0
		match arch:
			"bush": regrow = 3
			"tree": regrow = 4
			"vine": regrow = 3
		if cat == "seasonal" and arch == "tree":
			regrow = 5
		var value: int = _round5(BASE_VALUE[rarity] * (0.7 + days * 0.07) * (0.8 if regrow > 0 else 1.0))
		value = opts.get("value", value)
		var leaf := Color("5fae3f")
		match cat:
			"crystal": leaf = Color("b8a8e8")
			"ancient": leaf = Color("6a8a3a")
			"mythical": leaf = Color("4fbf8a")
			"exotic": leaf = Color("3f9f4a")
		if opts.has("leaf"):
			leaf = Color(opts["leaf"])
		var needs := ""
		match cat:
			"mythical": needs = "starlight_fertilizer"
			"crystal": needs = "crystal_dust"
			"ancient": needs = "ancient_compost"
		var seed_suffix := " Seeds"
		match arch:
			"tree": seed_suffix = " Sapling"
			"mushroom": seed_suffix = " Spores"
		if cat == "crystal":
			seed_suffix = " Geode"
		elif cat == "ancient":
			seed_suffix = " Ancient Seed"
		var lore: String = opts.get("lore", "")
		if lore == "":
			var pool: Array = LORE.get(cat, LORE["crop"])
			lore = pool[abs(hash(id)) % pool.size()] % name
		var d := {
			"name": name, "cat": cat, "rarity": rarity, "value": value, "lore": lore,
			"plant": true, "arch": arch, "c1": c1, "c2": c2, "leaf": leaf,
			"seasons": _parse_seasons(row[1]), "days": days, "regrow": regrow,
			"region": opts.get("region", region), "needs": needs,
			"shop": opts.get("shop", false), "shape": opts.get("shape", ""),
			"opts": opts, "seed_name": name + seed_suffix,
		}
		d["icon"] = _plant_icon_kind(d)
		_add(id, d)
		plant_ids.append(id)
		if cat == "flower":
			flower_ids.append(id)


func _plant_icon_kind(d: Dictionary) -> String:
	var o: Dictionary = d["opts"]
	match d["arch"]:
		"root": return "long_root" if o.get("long", false) else "round_root"
		"leafy": return "leaf_ball"
		"vine": return "pod" if o.get("pod", false) else "fruit"
		"gourd": return "big_fruit"
		"grain": return "bundle"
		"tall": return "cob" if d["shape"] == "corn" else "bloom"
		"bush": return "flower_cluster" if d["shape"] == "flowers" else ("tea" if d["shape"] == "tea" else "berries")
		"herb": return "sprig"
		"flower", "mythic":
			match d["shape"]:
				"fern": return "frond"
				"mandrake": return "mandrake"
				"worldtree": return "sapling"
				"puffs": return "puffs"
			return "bloom"
		"mushroom": return "mushroom"
		"tree":
			if d["shape"] == "oak": return "acorn_big"
			if d["shape"] == "sakura": return "bloom"
			return "fruit"
		"crystal": return "gem" if d["shape"] in ["shard", "prism"] else "crystal_bloom"
		"fern":
			if d["shape"] == "cone": return "cone"
			if d["shape"] == "moss": return "moss"
			return "frond"
		"exotic":
			match d["shape"]:
				"trap", "pitcher", "titan": return "trap"
				"cactus", "aloe": return "cactus"
				"bamboo": return "bamboo"
				"pineapple": return "pineapple"
			if o.get("fruit", "") == "flower": return "bloom"
			if o.get("fruit", "") == "none": return "leaf"
			return "fruit"
	return "fruit"


func _add_mutations() -> void:
	for fid in flower_ids:
		var base: Dictionary = items[fid]
		for kind in ["golden", "rainbow"]:
			var r: int = min(4, base["rarity"] + (2 if kind == "golden" else 3))
			var mult := 6 if kind == "golden" else 14
			var nm: String = ("Golden " if kind == "golden" else "Rainbow ") + base["name"]
			var lore := ""
			if kind == "golden":
				lore = "A rare golden mutation of the %s. It glimmers like a captured sunrise." % base["name"]
			else:
				lore = "An incredibly rare rainbow %s. Its petals shift through every color in the light." % base["name"]
			_add(kind + "_" + fid, {
				"name": nm, "cat": "mutation", "rarity": r, "value": int(base["value"]) * mult,
				"lore": lore, "base": fid, "mutation": kind, "icon": "mutation",
				"region": "Harvest a %s (mutation chance)" % base["name"],
			})


func _add_tools() -> void:
	for t in TOOL_ORDER:
		for i in 5:
			var def: Dictionary = TOOL_DEFS[t]
			_add("tool_%s_%d" % [t, i + 1], {
				"name": "%s %s" % [TOOL_TIERS[i], def["name"]], "cat": "tool", "rarity": i,
				"value": 0, "tool": t, "tier": i + 1, "icon": "tool",
				"lore": "Tier %d. %s" % [i + 1, def["desc"]],
				"region": "Upgrade at the Village Shop",
			})
	for f in FERTILIZERS:
		_add(f[0], {
			"name": f[1], "cat": "tool", "rarity": f[2], "value": int(f[3] * 0.4), "price": f[3],
			"fert": true, "c1": Color(f[4]), "icon": "fert", "lore": f[5], "region": "Village Shop / Foraging",
		})


func _add_decor() -> void:
	for d in DECOR:
		var flags: String = d[7]
		_add(d[0], {
			"name": d[1], "cat": "decor", "price": d[2], "rarity": d[3], "kind": d[4],
			"c1": Color(d[5]), "c2": Color(d[6]) if String(d[6]) != "" else Color(d[5]).darkened(0.3),
			"solid": flags.find("solid") >= 0, "floor": flags.find("floor") >= 0,
			"light": flags.find("light") >= 0, "lore": d[8], "value": int(d[2] * 0.3),
			"decor": true, "icon": "decor",
			"region": "Village Shop" if int(d[2]) > 0 else "Collection reward",
		})


func _add_treasures() -> void:
	for t in TREASURES:
		var regs: Array = Array(String(t[5]).split(","))
		_add(t[0], {
			"name": t[1], "cat": "treasure", "rarity": t[2], "kind": t[3], "c1": Color(t[4]),
			"regions": regs, "lore": t[6], "value": _round5(BASE_VALUE[t[2]] * 1.2),
			"icon": "treasure",
			"region": ", ".join(regs.map(func(r): return REGION_NAMES.get(r, r))),
		})


# ================================================================= QUERIES
func item(id: String) -> Dictionary:
	if id.begins_with("seed:"):
		return items.get(id.substr(5), {})
	return items.get(id, {})


func has_item(id: String) -> bool:
	return items.has(id.trim_prefix("seed:"))


func is_seed(key: String) -> bool:
	return key.begins_with("seed:")


func seed_key(plant_id: String) -> String:
	return "seed:" + plant_id


func display_name(key: String) -> String:
	var it := item(key)
	if it.is_empty():
		return key
	if is_seed(key):
		return it["seed_name"]
	return it["name"]


func rarity_of(key: String) -> int:
	var it := item(key)
	return int(it.get("rarity", 0))


func sell_price(key: String) -> int:
	var it := item(key)
	if it.is_empty():
		return 0
	if is_seed(key):
		return max(1, int(seed_price(key.substr(5)) * 0.4))
	return int(it.get("value", 0))


func seed_price(plant_id: String) -> int:
	var it: Dictionary = items[plant_id]
	return max(10, _round5(int(it["value"]) * 0.5))


func book_ids(cat: String) -> Array:
	var out := []
	for id in order:
		if items[id]["cat"] == cat:
			out.append(id)
	return out


func total_collectibles() -> int:
	return order.size()


func is_fertilizer(key: String) -> bool:
	return items.has(key) and items[key].get("fert", false)


func is_decor(key: String) -> bool:
	return items.has(key) and items[key].get("decor", false)


func in_season(plant_id: String, season: int) -> bool:
	return season in items[plant_id]["seasons"]


func season_text(plant_id: String) -> String:
	var s: Array = items[plant_id]["seasons"]
	if s.size() == 4:
		return "All seasons"
	return ", ".join(s.map(func(i): return SEASON_NAMES[i]))


func growing_conditions(id: String) -> String:
	var it: Dictionary = items[id]
	if not it.get("plant", false):
		return "Found: " + str(it.get("region", ""))
	var t := "Seasons: %s\nGrows in %d days" % [season_text(id), it["days"]]
	if int(it["regrow"]) > 0:
		t += " (regrows every %d)" % it["regrow"]
	if it["needs"] != "":
		t += "\nNeeds: " + items[it["needs"]]["name"]
	t += "\nSeeds found: " + REGION_NAMES.get(it["region"], it["region"])
	return t


## Weighted loot table for a region's forage spots.
func forage_table(region: String) -> Array:
	var out := []
	for id in plant_ids:
		var it: Dictionary = items[id]
		if it["region"] == region:
			out.append(["seed:" + id, FORAGE_WEIGHT[it["rarity"]]])
	for t in TREASURES:
		if region in String(t[5]).split(","):
			out.append([t[0], FORAGE_WEIGHT[t[2]] * 0.8])
	var fert_by_region := {
		"forest": "compost", "flower_fields": "quality_fertilizer", "mushroom_caves": "speed_gro",
		"fairy_garden": "starlight_fertilizer", "crystal_biome": "crystal_dust",
		"ancient_ruins": "ancient_compost", "mountains": "magic_mulch", "home": "compost",
		"village": "compost",
	}
	if fert_by_region.has(region):
		out.append([fert_by_region[region], 10.0])
	return out
