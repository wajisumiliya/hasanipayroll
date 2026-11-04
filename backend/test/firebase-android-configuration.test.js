import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

test('Flutter Firebase Android options match the Android application package',async()=>{
  const root=new URL('../../',import.meta.url);
  const gradle=await readFile(new URL('android/app/build.gradle.kts',root),'utf8');
  const packageName=/applicationId\s*=\s*"([^"]+)"/.exec(gradle)[1];
  const google=JSON.parse(await readFile(new URL('android/app/google-services.json',root),'utf8'));
  const client=google.client.find(c=>c.client_info.android_client_info.package_name===packageName);
  assert.ok(client,'Android package must be registered in Firebase');
  const options=await readFile(new URL('lib/firebase_options.dart',root),'utf8');
  const android=/static const FirebaseOptions android = FirebaseOptions\(([\s\S]*?)\);/.exec(options)[1];
  const field=name=>new RegExp(`${name}: '([^']+)'`).exec(android)[1];
  assert.equal(field('appId'),client.client_info.mobilesdk_app_id);
  assert.equal(field('projectId'),google.project_info.project_id);
  assert.equal(field('messagingSenderId'),google.project_info.project_number);
  assert.equal(field('apiKey'),client.api_key[0].current_key);
});
