"""
HIPAA-compliant encryption utilities for PHI (Protected Health Information).
Uses AES-256-GCM for encryption at rest.
"""
import os
import base64
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.backends import default_backend


class PHIEncryptor:
    """Handles encryption/decryption of PHI data at rest."""

    def __init__(self):
        key_b64 = os.getenv('PHI_ENCRYPTION_KEY')
        if not key_b64:
            raise ValueError("PHI_ENCRYPTION_KEY environment variable not set")
        self._key = base64.b64decode(key_b64)
        if len(self._key) != 32:
            raise ValueError("PHI_ENCRYPTION_KEY must be 32 bytes (256 bits)")
        self._aesgcm = AESGCM(self._key)

    def encrypt(self, plaintext: str) -> str:
        """
        Encrypt plaintext PHI data.
        Returns base64-encoded ciphertext with nonce prepended.
        """
        if not plaintext:
            return plaintext

        nonce = os.urandom(12)  # 96-bit nonce for GCM
        ciphertext = self._aesgcm.encrypt(nonce, plaintext.encode('utf-8'), None)
        # Prepend nonce to ciphertext
        encrypted_data = nonce + ciphertext
        return base64.b64encode(encrypted_data).decode('utf-8')

    def decrypt(self, encrypted_b64: str) -> str:
        """
        Decrypt base64-encoded ciphertext.
        Expects nonce prepended to ciphertext.
        """
        if not encrypted_b64:
            return encrypted_b64

        encrypted_data = base64.b64decode(encrypted_b64)
        nonce = encrypted_data[:12]
        ciphertext = encrypted_data[12:]
        plaintext = self._aesgcm.decrypt(nonce, ciphertext, None)
        return plaintext.decode('utf-8')


# Singleton instance
_encryptor = None


def get_encryptor() -> PHIEncryptor:
    """Get or create the PHI encryptor singleton."""
    global _encryptor
    if _encryptor is None:
        _encryptor = PHIEncryptor()
    return _encryptor


def encrypt_phi(value: str) -> str:
    """Convenience function to encrypt PHI."""
    return get_encryptor().encrypt(value)


def decrypt_phi(value: str) -> str:
    """Convenience function to decrypt PHI."""
    return get_encryptor().decrypt(value)


def hash_email(email: str) -> str:
    """Return a deterministic SHA-256 hex digest for email lookup.
    The PHI_ENCRYPTION_KEY is used as HMAC key so the hash is not reversible
    without the key."""
    import hashlib
    import hmac
    key = base64.b64decode(os.getenv('PHI_ENCRYPTION_KEY', ''))
    return hmac.new(key, email.strip().lower().encode('utf-8'), hashlib.sha256).hexdigest()
