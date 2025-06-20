module poet_market::poem_nft {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::url::{Self, Url};
    use sui::event;
    use std::string::{Self, String};
    use sui::table::{Self, Table};

    // Format tiers for poems
    const TIER_DIGITAL: u8 = 0;
    const TIER_PRINTED: u8 = 1;
    const TIER_HAND_TYPED: u8 = 2;

    // Error codes
    const EINVALID_POEM_LENGTH: u64 = 1;
    const EINVALID_TIER: u64 = 2;

    // The PoemNFT struct with actual poem content
    struct PoemNFT has key, store {
        id: UID,
        // Basic Metadata
        title: String,
        poet_name: String,
        creation_date: String,
        
        // Poem Content
        content: String,  // The actual poem text
        genre: String,    // E.g., "Sonnet", "Haiku", "Free Verse"
        language: String, // Language of the poem
        
        // Extended Metadata
        description: String,
        abstract: String,
        ipfs_url: Url,    // For additional media (audio, video, etc.)
        
        // Technical Metadata
        poet_id: address,
        format_tier: u8,
        poem_number: u64,
        
        // Optional Attributes
        dedication: String,
        notes: String
    }

    // Registry to track poets and their poems
    struct PoetRegistry has key {
        id: UID,
        // Map poet address to number of poems they've created
        poet_poems: Table<address, u64>
    }

    // Events
    struct PoemMinted has copy, drop {
        poem_id: address,
        title: String,
        poet_name: String,
        poet_address: address,
        tier: u8,
        poem_number: u64,
        genre: String
    }

    // Initialize the module
    fun init(ctx: &mut TxContext) {
        transfer::share_object(
            PoetRegistry {
                id: object::new(ctx),
                poet_poems: table::new(ctx)
            }
        );
    }

    // Create a new poem NFT with full content
    public fun create_poem(
        registry: &mut PoetRegistry,
        // Basic Info
        title: vector<u8>,
        poet_name: vector<u8>,
        creation_date: vector<u8>,
        // Content
        content: vector<u8>,
        genre: vector<u8>,
        language: vector<u8>,
        // Metadata
        description: vector<u8>,
        abstract: vector<u8>,
        ipfs_url: vector<u8>,
        // Format
        format_tier: u8,
        // Optional
        dedication: vector<u8>,
        notes: vector<u8>,
        ctx: &mut TxContext
    ) {
        // Validate inputs
        assert!(std::vector::length(&content) > 0, EINVALID_POEM_LENGTH);
        assert!(format_tier <= TIER_HAND_TYPED, EINVALID_TIER);
        
        let sender = tx_context::sender(ctx);
        
        // Get or initialize poet's poem count
        if (!table::contains(&registry.poet_poems, sender)) {
            table::add(&mut registry.poet_poems, sender, 0);
        };
        
        // Increment poet's poem count
        let poem_count = table::borrow_mut(&mut registry.poet_poems, sender);
        *poem_count = *poem_count + 1;

        // Create the PoemNFT with full metadata
        let poem = PoemNFT {
            id: object::new(ctx),
            title: string::utf8(title),
            poet_name: string::utf8(poet_name),
            creation_date: string::utf8(creation_date),
            content: string::utf8(content),
            genre: string::utf8(genre),
            language: string::utf8(language),
            description: string::utf8(description),
            abstract: string::utf8(abstract),
            ipfs_url: url::new_unsafe_from_bytes(ipfs_url),
            poet_id: sender,
            format_tier,
            poem_number: *poem_count,
            dedication: string::utf8(dedication),
            notes: string::utf8(notes)
        };

        // Emit creation event
        event::emit(PoemMinted {
            poem_id: object::uid_to_address(&poem.id),
            title: poem.title,
            poet_name: poem.poet_name,
            poet_address: sender,
            tier: format_tier,
            poem_number: *poem_count,
            genre: poem.genre
        });

        // Transfer the NFT to the creator
        transfer::transfer(poem, sender);
    }

    // === View Functions ===
    
    public fun get_title(poem: &PoemNFT): &String { &poem.title }
    public fun get_poet_name(poem: &PoemNFT): &String { &poem.poet_name }
    public fun get_creation_date(poem: &PoemNFT): &String { &poem.creation_date }
    public fun get_content(poem: &PoemNFT): &String { &poem.content }
    public fun get_genre(poem: &PoemNFT): &String { &poem.genre }
    public fun get_language(poem: &PoemNFT): &String { &poem.language }
    public fun get_description(poem: &PoemNFT): &String { &poem.description }
    public fun get_abstract(poem: &PoemNFT): &String { &poem.abstract }
    public fun get_ipfs_url(poem: &PoemNFT): &Url { &poem.ipfs_url }
    public fun get_poet_id(poem: &PoemNFT): address { poem.poet_id }
    public fun get_format_tier(poem: &PoemNFT): u8 { poem.format_tier }
    public fun get_poem_number(poem: &PoemNFT): u64 { poem.poem_number }
    public fun get_dedication(poem: &PoemNFT): &String { &poem.dedication }
    public fun get_notes(poem: &PoemNFT): &String { &poem.notes }

    public fun get_poet_poem_count(registry: &PoetRegistry, poet: address): u64 {
        if (table::contains(&registry.poet_poems, poet)) {
            *table::borrow(&registry.poet_poems, poet)
        } else {
            0
        }
    }
} 