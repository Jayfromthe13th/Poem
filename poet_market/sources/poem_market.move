module poet_market::poem_market {
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::event;
    use sui::dynamic_field as df;
    use std::option::{Self, Option};

    // Error codes
    const ENO_LISTING_EXISTS: u64 = 0;
    const ELISTING_NOT_FOUND: u64 = 1;
    const EINCORRECT_PAYMENT: u64 = 2;
    const ENOT_OWNER: u64 = 3;
    const EZERO_PRICE: u64 = 4;

    // Constants for fee calculation
    const SELLER_FEE_PERCENTAGE: u64 = 70;
    const PROTOCOL_FEE_PERCENTAGE: u64 = 30;
    const BASIS_POINTS: u64 = 100;

    // Events
    struct ListingCreated has copy, drop {
        id: ID,
        poem_id: ID,
        price: u64,
        seller: address
    }

    struct ListingRemoved has copy, drop {
        id: ID,
        poem_id: ID
    }

    struct PoemSold has copy, drop {
        id: ID,
        poem_id: ID,
        seller: address,
        buyer: address,
        price: u64
    }

    // Listing object to track NFTs listed for sale
    struct Listing has key {
        id: UID,
        poem_id: ID,
        price: u64,
        owner: address
    }

    // Protocol fee collector and NFT storage
    struct MarketPlace has key {
        id: UID,
        balance: Balance<SUI>
    }

    // Key for storing NFTs in dynamic fields
    struct NFTKey has copy, drop, store { id: ID }

    // === Functions ===

    fun init(ctx: &mut TxContext) {
        // Create and share the marketplace
        transfer::share_object(MarketPlace {
            id: object::new(ctx),
            balance: balance::zero()
        });
    }

    // List a poem NFT for sale
    public fun list_poem<T: key + store>(
        nft: T,
        price: u64,
        marketplace: &mut MarketPlace,
        ctx: &mut TxContext
    ) {
        assert!(price > 0, EZERO_PRICE);
        
        let nft_id = object::id(&nft);
        let listing = Listing {
            id: object::new(ctx),
            poem_id: nft_id,
            price,
            owner: tx_context::sender(ctx)
        };

        // Store the NFT in the marketplace using dynamic fields
        df::add(&mut marketplace.id, NFTKey { id: nft_id }, nft);

        event::emit(ListingCreated {
            id: object::id(&listing),
            poem_id: nft_id,
            price,
            seller: tx_context::sender(ctx)
        });

        transfer::share_object(listing);
    }

    // Remove a listing
    public fun delist_poem<T: key + store>(
        listing: &mut Listing,
        marketplace: &mut MarketPlace,
        ctx: &mut TxContext
    ) {
        assert!(listing.owner == tx_context::sender(ctx), ENOT_OWNER);

        // Remove and return the NFT to the owner
        let nft = df::remove<NFTKey, T>(&mut marketplace.id, NFTKey { id: listing.poem_id });
        transfer::public_transfer(nft, tx_context::sender(ctx));

        event::emit(ListingRemoved {
            id: object::id(listing),
            poem_id: listing.poem_id
        });

        // Delete the listing
        transfer::transfer(listing, tx_context::sender(ctx));
    }

    // Purchase a listed poem
    public fun purchase_poem<T: key + store>(
        listing: &mut Listing,
        payment: &mut Coin<SUI>,
        marketplace: &mut MarketPlace,
        ctx: &mut TxContext
    ) {
        let payment_amount = coin::value(payment);
        assert!(payment_amount >= listing.price, EINCORRECT_PAYMENT);

        // Calculate fees
        let total_amount = balance::split(coin::balance_mut(payment), listing.price);
        
        // Calculate protocol fee (30%)
        let protocol_fee = (listing.price * PROTOCOL_FEE_PERCENTAGE) / BASIS_POINTS;
        let protocol_fee_balance = balance::split(&mut total_amount, protocol_fee);
        balance::join(&mut marketplace.balance, protocol_fee_balance);

        // Rest goes to seller (70%)
        let seller_payment = Coin::from_balance(total_amount, ctx);
        transfer::public_transfer(seller_payment, listing.owner);

        // If there's remaining balance in the payment, return it to the buyer
        if (coin::value(payment) > 0) {
            transfer::public_transfer(payment, tx_context::sender(ctx));
        } else {
            coin::destroy_zero(payment);
        };

        // Transfer the NFT to the buyer
        let nft = df::remove<NFTKey, T>(&mut marketplace.id, NFTKey { id: listing.poem_id });
        transfer::public_transfer(nft, tx_context::sender(ctx));

        event::emit(PoemSold {
            id: object::id(listing),
            poem_id: listing.poem_id,
            seller: listing.owner,
            buyer: tx_context::sender(ctx),
            price: listing.price
        });

        // Delete the listing
        transfer::transfer(listing, tx_context::sender(ctx));
    }

    // === View Functions ===

    public fun get_listing_price(listing: &Listing): u64 {
        listing.price
    }

    public fun get_listing_owner(listing: &Listing): address {
        listing.owner
    }

    public fun get_poem_id(listing: &Listing): ID {
        object::id_from_address(object::id_address(&listing.poem_id))
    }
} 