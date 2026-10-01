import { before, after, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, collection, query, where, getDocs } from 'firebase/firestore';
import { ref, uploadBytes } from 'firebase/storage';
let env;
before(async()=>{
  env=await initializeTestEnvironment({projectId:'demo-rental',
    firestore:{host:'127.0.0.1',port:8085,rules:await readFile('../firestore.rules','utf8')},
    storage:{host:'127.0.0.1',port:9199,rules:await readFile('../storage.rules','utf8')}});
  await env.withSecurityRulesDisabled(async context=>{
    await setDoc(doc(context.firestore(),'conversations/1_2'),{members:['rental_1','rental_2']});
    await setDoc(doc(context.firestore(),'conversations/1_2/messages/msg'),{sender:'rental_1',text:'Hello'});
  });
});
after(async()=>env?.cleanup());
test('members can read their conversation and messages',async()=>{
  const db=env.authenticatedContext('rental_2').firestore();
  await assertSucceeds(getDoc(doc(db,'conversations/1_2/messages/msg')));
  await assertSucceeds(getDocs(query(collection(db,'conversations'),where('members','array-contains','rental_2'))));
});
test('another tenant and anonymous callers cannot read private chat',async()=>{
  await assertFails(getDoc(doc(env.authenticatedContext('rental_3').firestore(),'conversations/1_2')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'conversations/1_2/messages/msg')));
});
test('clients cannot forge messages or conversation membership',async()=>{
  const db=env.authenticatedContext('rental_2').firestore();
  await assertFails(setDoc(doc(db,'conversations/1_2/messages/forged'),{text:'forged',sender:'rental_1'}));
  await assertFails(setDoc(doc(db,'conversations/1_2'),{members:['rental_2','rental_3']}));
});
test('image uploads must belong to the caller and be an allowed MIME type',async()=>{
  const storage=env.authenticatedContext('rental_2').storage();
  await assertSucceeds(uploadBytes(ref(storage,'uploads/rental_2/image.png'),new Uint8Array([137,80,78,71]),{contentType:'image/png'}));
  await assertFails(uploadBytes(ref(storage,'uploads/rental_1/image.png'),new Uint8Array([1]),{contentType:'image/png'}));
  await assertFails(uploadBytes(ref(storage,'uploads/rental_2/script.html'),new Uint8Array([1]),{contentType:'text/html'}));
});
test('oversized images are rejected',async()=>{
  const storage=env.authenticatedContext('rental_2').storage();
  await assertFails(uploadBytes(ref(storage,'uploads/rental_2/large.jpg'),new Uint8Array(3*1024*1024),{contentType:'image/jpeg'}));
});
