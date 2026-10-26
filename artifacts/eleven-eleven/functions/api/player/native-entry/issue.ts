import { authenticatePlayer, corsHeaders, errorResponse, jsonResponse, optionsResponse, readJsonBody, type PlayerApiContext } from '../_shared';
import { requirePlayerDatabase } from '../_database';
import { issueNativeEntry } from '../_nativeEntry';

export async function onRequestOptions({request,env}: PlayerApiContext) { return optionsResponse(request,env); }
export async function onRequestPost({request,env}: PlayerApiContext) {
  const headers=corsHeaders(request,env);
  try {
    const {account}=await authenticatePlayer(request,env);
    const body=await readJsonBody<unknown>(request,{maxBytes:1024,tooLargeCode:'native_entry_too_large',tooLargeMessage:'Connection request is too large.'});
    return jsonResponse(await issueNativeEntry(requirePlayerDatabase(env),account.uid,body),200,headers);
  } catch(error) { return errorResponse(error,headers); }
}
