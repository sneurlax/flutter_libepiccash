use std::sync::Arc;
use mwc_util::Mutex;
use mwc_wallet_impls::{DefaultLCProvider, HTTPNodeClient};
use mwc_wallet_libwallet::{Error, WalletInst, Slate, SlateVersion, SlatePurpose};
use mwc_wallet_libwallet::slatepack::{Slatepacker, SlatepackArmor};
use mwc_keychain::ExtKeychain;
use ed25519_dalek::{PublicKey as DalekPublicKey, SecretKey as DalekSecretKey};
use mwc_util::secp::Secp256k1;

/// Wallet type (same as in wallet.rs).
pub type Wallet = Arc<
    Mutex<
        Box<
            dyn WalletInst<
                'static,
                DefaultLCProvider<'static, HTTPNodeClient, ExtKeychain>,
                HTTPNodeClient,
                ExtKeychain,
            >,
        >,
    >,
>;

/// Encode a slate into slatepack format.
/// 
/// # Arguments
/// * `slate_json` - JSON representation of the slate
/// * `recipient_address` - Optional recipient address for encryption (None for unencrypted).
/// 
/// # Returns
/// * Result containing the armored slatepack string or error.
pub fn encode_slatepack(
    slate_json: &str,
    _recipient_address: Option<&str>,
) -> Result<String, Error> {
    // Deserialize the slate to validate it.
    let slate = Slate::deserialize_upgrade_plain(slate_json)?;
    
    // Create a dummy sender key for unencrypted slatepacks.
    let dummy_secret = DalekSecretKey::from_bytes(&[1u8; 32])
        .map_err(|e| Error::GenericError(format!("Failed to create dummy key: {:?}", e)))?;
    let dummy_sender = DalekPublicKey::from(&dummy_secret);
    
    // Create secp context.
    let secp = Secp256k1::new();
    
    let armored = Slatepacker::encrypt_to_send(
        slate,
        SlateVersion::SP,
        SlatePurpose::FullSlate,
        dummy_sender,
        None, // No recipient = unencrypted.
        &dummy_secret,
        false, // use_test_rng = false.
        &secp,
    )?;
    
    Ok(armored)
}

/// Decode a slatepack into slate JSON using official MWC wallet library.
/// 
/// # Arguments
/// * `slatepack_str` - The slatepack string to decode.
/// 
/// # Returns
/// * Result containing tuple of (slate_json, sender_info, recipient_info) or error.
pub fn decode_slatepack(
    slatepack_str: &str,
) -> Result<(String, Option<String>, Option<String>), Error> {
    // Create a dummy key for decoding (since we use it for unencrypted slatepacks).
    let dummy_secret = DalekSecretKey::from_bytes(&[1u8; 32])
        .map_err(|e| Error::GenericError(format!("Failed to create dummy key: {:?}", e)))?;
    
    // Create secp context.
    let secp = Secp256k1::new();
    
    let slatepacker = Slatepacker::decrypt_slatepack(
        slatepack_str.as_bytes(),
        &dummy_secret,
        0, // height - use 0 for testing
        &secp,
    )?;
    
    // Extract sender and recipient info before consuming slatepacker.
    let sender_info = slatepacker.get_sender()
        .map(|key| format!("{:?}", key)); // Convert public key to string representation.
    let recipient_info = slatepacker.get_recipient()
        .map(|key| format!("{:?}", key)); // Convert public key to string representation.
    
    // Extract the slate and convert to JSON.
    let slate = slatepacker.to_result_slate();
    let slate_json = serde_json::to_string(&slate)
        .map_err(|e| Error::GenericError(format!("Failed to serialize slate to JSON: {}", e)))?;
    
    Ok((slate_json, sender_info, recipient_info))
}