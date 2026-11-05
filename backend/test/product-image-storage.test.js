const assert = require('node:assert/strict');
const test = require('node:test');

const {
  imageIdFromReference,
  imageReference,
  safeImagePath,
} = require('../routes/product_images');

test('product image references are opaque UUIDs and never accept local paths', () => {
  const id = '7f8db6d1-3a69-4d68-a0d1-7f2600c08ed7';
  const reference = imageReference(id);
  assert.equal(reference, `server-image:${id}`);
  assert.equal(imageIdFromReference(reference), id);
  assert.equal(imageIdFromReference('C:\\Users\\client\\photo.jpg'), null);
  assert.equal(imageIdFromReference('../../etc/passwd'), null);
});

test('product image storage paths cannot escape the private storage root', () => {
  assert.equal(safeImagePath('../../etc/passwd'), null);
  assert.equal(safeImagePath('tenant-a/photo.jpg')?.includes('tenant-a'), true);
});
