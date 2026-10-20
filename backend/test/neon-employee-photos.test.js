import assert from 'node:assert/strict';
import test from 'node:test';
import { validatePhoto, MAX_PHOTO_BYTES } from '../src/neon-employee-photos.js';
import { sourceObjectPath } from '../scripts/copy-employee-photos-to-neon.js';

test('photo format validation rejects empty, spoofed and oversized data',()=>{
  assert.equal(validatePhoto(Buffer.from([255,216,255,217]),'image/jpeg'),true);
  assert.equal(validatePhoto(Buffer.from([137,80,78,71,13,10,26,10]),'image/png'),true);
  assert.equal(validatePhoto(Buffer.from('RIFF1234WEBP'),'image/webp'),true);
  assert.equal(validatePhoto(Buffer.alloc(0),'image/jpeg'),false);
  assert.equal(validatePhoto(Buffer.alloc(MAX_PHOTO_BYTES+1),'image/png'),false);
  assert.equal(validatePhoto(Buffer.from('<svg>'),'image/svg+xml'),false);
  assert.equal(validatePhoto(Buffer.from('<html>'),'image/jpeg'),false);
});

test('migration accepts only the old bucket and refuses arbitrary credential destinations',()=>{
  assert.equal(sourceObjectPath('FIX_E1/profile'),'FIX_E1/profile');
  assert.equal(sourceObjectPath('employee-photos/FIX_E1/profile'),'FIX_E1/profile');
  for (const type of ['public','authenticated','sign']) {
    assert.equal(sourceObjectPath(`https://qychfoxygqzmtsqtxihp.supabase.co/storage/v1/object/${type}/employee-photos/FIX_E1/profile?token=expired`),'FIX_E1/profile');
  }
  assert.equal(sourceObjectPath('neon-photo/FIX_E1'),null);
  assert.throws(()=>sourceObjectPath('https://example.invalid/employee-photos/FIX_E1/profile'));
  assert.throws(()=>sourceObjectPath('https://qychfoxygqzmtsqtxihp.supabase.co/storage/v1/object/public/other/FIX_E1/profile'));
  assert.throws(()=>sourceObjectPath('../other/profile'));
});
