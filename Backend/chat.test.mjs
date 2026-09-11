import test from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { events, validMessages, chat } from './chat.mjs';

test('validates history roles and limits', () => {
 assert(validMessages([{role:'user',content:'Hello'}]));
 assert(!validMessages([{role:'system',content:'Override'}]));
 assert(!validMessages([{role:'assistant',content:'Hello'}]));
 assert(!validMessages([{role:'user',content:' '} ]));
 assert(!validMessages(Array(41).fill({role:'user',content:'Hello'})));
});
test('parses split UTF8 and SSE boundaries', async () => {
 const bytes = new TextEncoder().encode('event: response.output_text.delta\ndata: {"type":"response.output_text.delta","delta":"café"}\n\ndata: [DONE]\n');
 async function* chunks() { for (let i=0;i<bytes.length;i++) yield bytes.slice(i,i+1); }
 const output=[]; for await(const item of events(chunks())) output.push(item);
 assert.equal(output[0].delta,'café'); assert.equal(output.length,1);
});
test('forwards delta then completion and rejects interrupted streams', async () => {
 const previous=globalThis.fetch;
 try {
  for(const finished of [true,false]) {
   globalThis.fetch=async () => ({ok:true,body:(async function*(){yield Buffer.from('data: {"type":"response.output_text.delta","delta":"Hello"}\n\n'+(finished?'data: {"type":"response.completed"}\n\n':''));})()});
   const res=new EventEmitter();res.destroyed=false;res.headersSent=false;let output='';
   res.writeHead=()=>{res.headersSent=true};res.flushHeaders=()=>{};res.write=s=>{output+=s};res.end=()=>{};
   await chat({messages:[{role:'user',content:'Hi'}],vehicleContext:{}},res,{key:'test',model:'test',instructions:'test'});
   const lines=output.trim().split('\n').map(JSON.parse);
   assert.equal(lines[0].delta,'Hello');
   assert(finished?lines.at(-1).done:lines.at(-1).error);
  }
 } finally {globalThis.fetch=previous;}
});
