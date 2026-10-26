import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync, type SQLInputValue } from 'node:sqlite';
import { it } from 'node:test';
import type { PlayerDatabase, PlayerDatabaseStatement } from '../../functions/api/player/_database';
import { exchangeNativeEntry, issueNativeEntry, nativeEntryDigest } from '../../functions/api/player/_nativeEntry';

class SqliteDatabase implements PlayerDatabase {
  sqlite=new DatabaseSync(':memory:');
  constructor() {
    for(const name of ['0027_opening_gateway_receipts.sql','0028_native_entry_grants.sql'])
      this.sqlite.exec(readFileSync(new URL('../../migrations/'+name,import.meta.url),'utf8'));
  }
  prepare(query:string):PlayerDatabaseStatement {
    const prepared=this.sqlite.prepare(query);
    let values: SQLInputValue[]=[];
    const statement:PlayerDatabaseStatement={
      bind:(...args)=>{values=args as SQLInputValue[];return statement;},
      first:async<T>()=>(prepared.get(...values) as T|undefined)??null,
      all:async<T>()=>({success:true,results:prepared.all(...values) as T[]}),
      run:async()=>({success:true,meta:{changes:Number(prepared.run(...values).changes)}}),
    };
    return statement;
  }
  async batch<T>(statements:PlayerDatabaseStatement[]) { return Promise.all(statements.map(s=>s.run<T>())); }
  receipt(uid='owner') { this.sqlite.prepare("INSERT INTO player_opening_recovery_receipts VALUES (?,?,?,1,'2026-10-18T00:00:00Z')").run(uid,'receipt-'+uid,'opening_cover_reconstruction_v1'); }
}

it('requires the authenticated account receipt; rejects client-authored receipt and malformed challenges',async()=>{
  const db=new SqliteDatabase();
  const challenge=await nativeEntryDigest('v'.repeat(64));
  await assert.rejects(issueNativeEntry(db,'owner',{challenge,receiptId:'fake'}),{code:'native_entry_unavailable'});
  db.receipt('other');
  await assert.rejects(issueNativeEntry(db,'owner',{challenge}),{code:'native_entry_unavailable'});
  await assert.rejects(issueNativeEntry(db,'other',{challenge:'plain-verifier'}),{code:'native_entry_invalid'});
});

it('S256 proof binds a random, hashed, five-minute single-use grant; a wrong proof does not burn it',async()=>{
  const db=new SqliteDatabase(); db.receipt();
  const verifier='secret-device-proof'.repeat(4);
  const grant=await issueNativeEntry(db,'owner',{challenge:await nativeEntryDigest(verifier)},1000);
  assert.equal(grant.expiresAt,301000);
  assert.equal(grant.code.length,43);
  assert.equal((db.sqlite.prepare('SELECT code_hash FROM player_native_entry_grants').get() as {code_hash:string}).code_hash,await nativeEntryDigest(grant.code));
  await assert.rejects(exchangeNativeEntry(db,{code:grant.code,verifier:'x'.repeat(64)},2000),{code:'native_entry_invalid'});
  const results=await Promise.allSettled([exchangeNativeEntry(db,{code:grant.code,verifier},2000),exchangeNativeEntry(db,{code:grant.code,verifier},2000)]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  const success=results.find(r=>r.status==='fulfilled');
  assert.deepEqual(success?.status==='fulfilled'&&success.value,{scope:'native-chapter-entry',coverReceiptId:'receipt-owner',entryConfirmed:true});
});

it('expires at the exact deadline, rejects missing codes, and bounds concurrent issuance in SQL',async()=>{
  const db=new SqliteDatabase(); db.receipt();
  const verifier='v'.repeat(64), challenge=await nativeEntryDigest(verifier);
  const grant=await issueNativeEntry(db,'owner',{challenge},1000);
  await assert.rejects(exchangeNativeEntry(db,{code:grant.code,verifier},301000),{code:'native_entry_invalid'});
  await assert.rejects(exchangeNativeEntry(db,{code:'z'.repeat(43),verifier},2000),{code:'native_entry_invalid'});
  const results=await Promise.allSettled(Array.from({length:8},()=>issueNativeEntry(db,'owner',{challenge},2000)));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,4);
  assert.equal((db.sqlite.prepare('SELECT COUNT(*) AS n FROM player_native_entry_grants').get() as {n:number}).n,5);
  assert.ok(await issueNativeEntry(db,'owner',{challenge},302000));
  assert.equal((db.sqlite.prepare('SELECT COUNT(*) AS n FROM player_native_entry_grants').get() as {n:number}).n,1);
});

it('a title tap receipt cannot replace the played cover prerequisite',async()=>{
  const db=new SqliteDatabase(), verifier='v'.repeat(64);
  db.sqlite.prepare("INSERT INTO player_opening_recovery_receipts VALUES ('title-only','title-only','opening_title_entry_v2',2,'2026-10-18')").run();
  await assert.rejects(issueNativeEntry(db,'title-only',{challenge:await nativeEntryDigest(verifier)}),{code:'native_entry_unavailable'});
});
