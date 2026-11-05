const express = require('express');
const crypto = require('crypto');
const fs = require('fs/promises');
const { createReadStream } = require('fs');
const path = require('path');
const { query, execute } = require('../db');
const {
  requireActiveBusiness,
  requireManagementRole,
} = require('../security/business_access');

const router = express.Router();
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const IMAGE_TYPES = new Map([
  ['image/jpeg', 'jpg'],
  ['image/png', 'png'],
  ['image/webp', 'webp'],
]);
const REFERENCE_PREFIX = 'server-image:';
const storageRoot = path.resolve(
  process.env.PRODUCT_IMAGE_STORAGE_PATH || path.join(__dirname, '..', 'storage', 'product_images'),
);

function normalizedContentType(value) {
  return String(value || '').split(';')[0].trim().toLowerCase();
}

function imageReference(id) {
  return `${REFERENCE_PREFIX}${id}`;
}

function imageIdFromReference(value) {
  const match = String(value || '').match(/^server-image:([0-9a-f-]{36})$/i);
  return match ? match[1] : null;
}

function safeImagePath(storageKey) {
  const candidate = path.resolve(storageRoot, String(storageKey || ''));
  const allowedPrefix = `${storageRoot}${path.sep}`;
  return candidate.startsWith(allowedPrefix) ? candidate : null;
}

router.use(requireActiveBusiness);

// Files are deliberately stored outside any public static directory. Uploads
// use raw image bytes rather than multipart middleware to keep the API small,
// bounded, and independent from a public object-store bucket.
router.post(
  '/',
  requireManagementRole,
  express.raw({ type: 'image/*', limit: MAX_IMAGE_BYTES }),
  async (req, res) => {
    const contentType = normalizedContentType(req.headers['content-type']);
    const extension = IMAGE_TYPES.get(contentType);
    if (!extension) {
      return res.status(415).json({
        success: false,
        message: 'Use a JPEG, PNG, or WebP product image.',
      });
    }
    if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
      return res.status(400).json({ success: false, message: 'A product image is required.' });
    }
    if (req.body.length > MAX_IMAGE_BYTES) {
      return res.status(413).json({ success: false, message: 'Product images must be 5 MB or smaller.' });
    }

    const id = crypto.randomUUID();
    const businessId = req.businessContext.businessId;
    const storageKey = path.posix.join(businessId, `${id}.${extension}`);
    const filePath = safeImagePath(storageKey);
    const temporaryPath = `${filePath}.uploading`;
    try {
      await fs.mkdir(path.dirname(filePath), { recursive: true });
      await fs.writeFile(temporaryPath, req.body, { flag: 'wx' });
      await fs.rename(temporaryPath, filePath);
      await execute(
        `INSERT INTO product_images
          (id, business_id, storage_key, content_type, byte_size, created_by)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [id, businessId, storageKey, contentType, req.body.length, req.businessContext.userId],
      );
      return res.status(201).json({
        success: true,
        imageRef: imageReference(id),
        imageId: id,
        byteSize: req.body.length,
      });
    } catch (error) {
      await fs.unlink(temporaryPath).catch(() => {});
      await fs.unlink(filePath).catch(() => {});
      console.error('Product image upload error:', error.message);
      return res.status(500).json({ success: false, message: 'Unable to store the product image securely.' });
    }
  },
);

router.get('/:id', async (req, res) => {
  const imageId = String(req.params.id || '');
  if (!/^[0-9a-f-]{36}$/i.test(imageId)) {
    return res.status(404).json({ success: false, message: 'Product image not found.' });
  }
  try {
    const [image] = await query(
      `SELECT storage_key, content_type, byte_size
         FROM product_images
        WHERE id = ? AND business_id = ? LIMIT 1`,
      [imageId, req.businessContext.businessId],
    );
    const filePath = image ? safeImagePath(image.storage_key) : null;
    if (!image || !filePath) {
      return res.status(404).json({ success: false, message: 'Product image not found.' });
    }
    await fs.access(filePath);
    res.set({
      'Content-Type': image.content_type,
      'Content-Length': String(image.byte_size),
      'Cache-Control': 'private, max-age=300',
      'X-Content-Type-Options': 'nosniff',
    });
    return createReadStream(filePath).pipe(res);
  } catch (error) {
    if (error?.code === 'ENOENT') {
      return res.status(404).json({ success: false, message: 'Product image not found.' });
    }
    console.error('Product image read error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load the product image.' });
  }
});

router.delete('/:id', requireManagementRole, async (req, res) => {
  const imageId = String(req.params.id || '');
  if (!/^[0-9a-f-]{36}$/i.test(imageId)) {
    return res.status(404).json({ success: false, message: 'Product image not found.' });
  }
  try {
    const [image] = await query(
      `SELECT storage_key FROM product_images WHERE id = ? AND business_id = ? LIMIT 1`,
      [imageId, req.businessContext.businessId],
    );
    if (!image) return res.status(404).json({ success: false, message: 'Product image not found.' });
    await execute('DELETE FROM product_images WHERE id = ? AND business_id = ?', [imageId, req.businessContext.businessId]);
    const filePath = safeImagePath(image.storage_key);
    if (filePath) await fs.unlink(filePath).catch(() => {});
    return res.json({ success: true });
  } catch (error) {
    console.error('Product image deletion error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to delete the product image.' });
  }
});

module.exports = { router, imageIdFromReference, imageReference, safeImagePath };
