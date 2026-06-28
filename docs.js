
function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');}
function lines(raw){return String(raw||'').split('\n').map(function(s){return s.trim();}).filter(Boolean);}
function pipes(raw){return lines(raw).map(function(l){var i=l.indexOf('|');return i<0?[l.trim(),'']:[l.slice(0,i).trim(),l.slice(i+1).trim()];});}
function docProposal(c){
  var gaps=lines(c.gaps_raw),dl=pipes(c.deliverables_raw),tl=pipes(c.timeline_raw),li=pipes(c.line_items_raw);
  var h='<h2 style="font-size:1.7rem;margin-bottom:8px">Proposal #'+esc(c.proposal_num||'')+'</h2><p style="margin-bottom:18px">Prepared for '+esc(c.business||'')+'.</p>';
  if(gaps.length){h+='<div class="card"><div class="eyebrow">Where you are at</div>'+gaps.map(function(g){return '<p style="margin-bottom:6px">• '+esc(g)+'</p>';}).join('')+'</div>';}
  if(dl.length){h+='<div class="card"><div class="eyebrow">What is included</div>'+dl.map(function(d){return '<p style="margin-bottom:8px"><strong style="color:var(--ink);font-family:var(--font-d)">'+esc(d[0])+'</strong><br><span style="font-size:.88rem">'+esc(d[1])+'</span></p>';}).join('')+'</div>';}
  if(tl.length){h+='<div class="card"><div class="eyebrow">Timeline</div>'+tl.map(function(t){return '<p style="margin-bottom:6px"><strong style="color:var(--accent);font-family:var(--font-m);font-size:.7rem;letter-spacing:.1em;text-transform:uppercase">'+esc(t[0])+'</strong> &nbsp;'+esc(t[1])+'</p>';}).join('')+'</div>';}
  if(li.length||c.total){h+='<div class="card"><div class="eyebrow">Investment</div>'+li.map(function(x){return '<p style="display:flex;justify-content:space-between;margin-bottom:6px"><span>'+esc(x[0])+'</span><strong style="color:var(--ink)">'+esc(x[1])+'</strong></p>';}).join('')+'<p style="display:flex;justify-content:space-between;border-top:2px solid var(--ink);margin-top:8px;padding-top:10px"><strong style="color:var(--ink)">Total</strong><strong class="chrome-text" style="font-family:var(--font-d);font-size:1.3rem">'+esc(c.total||c.subtotal||'')+'</strong></p></div>';}
  h+='<div class="dark"><h3>90-day guarantee</h3><p>If you do not see measurable improvement in leads, calls, or rankings within 90 days of launch, we work an additional month at no charge.</p></div>';
  return h;
}
function docAgreement(c){
  var scope=lines(c.scope_raw);
  var h='<h2 style="font-size:1.7rem;margin-bottom:8px">Service Agreement #'+esc(c.agreement_num||'')+'</h2><p style="margin-bottom:18px">Between Cursor Cat Digital and '+esc(c.business||'')+'. Plain English, fair to both sides.</p>';
  function cl(n,t,b){return '<div class="card"><div class="eyebrow">'+n+'. '+esc(t)+'</div>'+b+'</div>';}
  h+=cl(1,'Scope of Work','<p>Services in Proposal #'+esc(c.proposal_num||'')+(scope.length?':</p>'+scope.map(function(s){return '<p style="margin:4px 0">→ '+esc(s)+'</p>';}).join(''):'.</p>')+'<p style="margin-top:6px">Anything outside this scope is quoted separately first.</p>');
  h+=cl(2,'Payment','<p>Total '+esc(c.total||c.subtotal||'')+' CAD: 50% deposit ('+esc(c.deposit||'')+') on signing, 50% balance ('+esc(c.balance||'')+') on delivery.</p>');
  h+=cl(3,'Timeline','<p>Completed within '+esc(c.weeks||'')+' weeks of signed agreement, deposit, intake and access.</p>');
  h+=cl(4,'Your Responsibilities','<p>Complete intake within 48h, transfer access at kick-off, feedback within 3 business days, supply content within 5 business days.</p>');
  h+=cl(5,'90-Day Guarantee','<p>No measurable improvement in 90 days → one extra month at no charge. Requires agreed ad spend and no unauthorized changes.</p>');
  h+=cl(6,'Ownership','<p>On final payment you own all deliverables. We may show the work in our portfolio. All logins are yours.</p>');
  h+=cl(7,'Confidentiality','<p>Both parties keep proprietary information confidential for 2 years after the engagement.</p>');
  h+=cl(8,'Termination','<p>Retainers: 14 days notice, no fee. Projects: deposit non-refundable; past 50% progress the full fee applies.</p>');
  h+=cl(9,'Liability','<p>Liability is capped at fees paid in the prior 30 days. Not liable for algorithm changes or third-party outages.</p>');
  h+=cl(10,'Governing Law','<p>Governed by the laws of Alberta, Canada.</p>');
  return h;
}
