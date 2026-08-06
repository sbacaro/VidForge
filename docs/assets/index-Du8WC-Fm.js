(function(){const e=document.createElement("link").relList;if(e&&e.supports&&e.supports("modulepreload"))return;for(const r of document.querySelectorAll('link[rel="modulepreload"]'))s(r);new MutationObserver(r=>{for(const o of r)if(o.type==="childList")for(const l of o.addedNodes)l.tagName==="LINK"&&l.rel==="modulepreload"&&s(l)}).observe(document,{childList:!0,subtree:!0});function n(r){const o={};return r.integrity&&(o.integrity=r.integrity),r.referrerPolicy&&(o.referrerPolicy=r.referrerPolicy),r.crossOrigin==="use-credentials"?o.credentials="include":r.crossOrigin==="anonymous"?o.credentials="omit":o.credentials="same-origin",o}function s(r){if(r.ep)return;r.ep=!0;const o=n(r);fetch(r.href,o)}})();const f=[{id:"archive-pure",name:"Archive Pure",mark:"I",blurb:"Highest available YouTube stream.",quality:"max"},{id:"crystal",name:"Crystal",mark:"II",blurb:"Top clarity progressive stream.",quality:"max"},{id:"tempered",name:"Tempered",mark:"III",blurb:"Cap around 1080p for everyday use.",quality:"1080"},{id:"audio-ingot",name:"Audio Ingot",mark:"IV",blurb:"Best audio-only track.",quality:"audio"}];function m(t){return f.find(e=>e.id===t)??f[0]}function k(){return crypto.randomUUID()}function w(t){switch(t){case"queued":return"Queued";case"prospecting":return"Prospecting";case"smelting":return"Smelting";case"quenching":return"Quenching";case"finished":return"Forged";case"failed":return"Cracked"}}const q=["https://api.piped.private.coffee","https://pipedapi.adminforge.de","https://pipedapi.kavin.rocks"];async function S(){return navigator.onLine}async function L(t,e){e({phase:"prospecting",progress:.1,status:"Reading ore veins in the cloud…"});const n=T(t.url);if(!n)throw new Error("Free cloud engine supports YouTube links only right now.");const s=m(t.alloy);e({phase:"smelting",progress:.35,status:`Smelting ${s.name}…`});const r=await $(n),o=E(r,t.alloy);if(!o?.url)throw new Error("No suitable stream found for this alloy.");e({phase:"quenching",progress:.8,title:r.title||t.title,status:o.quality?`Quenching ${o.quality}…`:"Opening download…"}),e({phase:"finished",progress:1,title:r.title||t.title,downloadUrl:o.url,status:"Ready — tap Download"}),window.open(o.url,"_blank","noopener,noreferrer")}async function $(t){let e="All cloud resolvers failed.";for(const n of q)try{const s=await fetch(`${n}/streams/${t}`,{headers:{Accept:"application/json"}});if(!s.ok){e=`${n} HTTP ${s.status}`;continue}const r=await s.json();if(r.error){e=r.error;continue}if(!((r.videoStreams?.length??0)+(r.audioStreams?.length??0))){e="Empty stream list";continue}return r}catch(s){e=s instanceof Error?s.message:String(s)}throw new Error(e)}function E(t,e){const n=t.videoStreams??[],s=t.audioStreams??[];if(e==="audio-ingot"){const i=[...s].sort((d,b)=>(b.bitrate??0)-(d.bitrate??0))[0];return i?.url?{url:i.url,quality:i.quality??`${i.bitrate??"?"}bps`}:null}const r=n.filter(i=>i.videoOnly===!1&&i.url),o=r.length?r:n.filter(i=>i.url);if(!o.length)return null;const l=o.map(i=>({v:i,h:I(i.quality)})).sort((i,d)=>d.h-i.h||(d.v.bitrate??0)-(i.v.bitrate??0));let u=l[0];return e==="tempered"&&(u=l.find(i=>i.h>0&&i.h<=1080)??l.find(i=>i.h===720)??l[0]),{url:u.v.url,quality:u.v.quality??`${u.h}p`}}function I(t){if(!t)return 0;const e=t.match(/(\d{3,4})/);return e?Number(e[1]):0}function T(t){try{const e=new URL(t),n=e.hostname.replace(/^www\./,"");if(n==="youtu.be")return e.pathname.split("/").filter(Boolean)[0]??null;if(n.endsWith("youtube.com")||n.endsWith("youtube-nocookie.com")||n==="m.youtube.com"){if(e.searchParams.get("v"))return e.searchParams.get("v");const s=e.pathname.split("/").filter(Boolean);if(["shorts","embed","live"].includes(s[0]??""))return s[1]??null}}catch{}return/^[\w-]{11}$/.test(t.trim())?t.trim():null}const g=document.querySelector("#app");if(!g)throw new Error("#app missing");const a={selected:"archive-pure",jobs:[],online:!1,busy:!1};g.innerHTML=`
  <div class="stage">
    <div class="glow" aria-hidden="true"></div>
    <div class="sparks" id="sparks" aria-hidden="true"></div>
    <div class="shell">
      <header class="topbar">
        <div class="brand">
          <strong>VIDFORGE</strong>
          <span>100% browser. Hosted on GitHub Pages. Nothing to install. · v3</span>
        </div>
      </header>

      <section class="furnace" aria-label="Forge controls">
        <div class="field-label">Ore</div>
        <div class="ore-row">
          <input id="url" type="url" placeholder="Paste a YouTube URL…" autocomplete="off" />
          <button class="strike" id="strike" type="button">Strike</button>
        </div>

        <div class="field-label">Alloy</div>
        <div class="ingots" id="ingots" role="radiogroup" aria-label="Alloy"></div>

        <div class="statusline">
          <div class="pill"><span class="dot" id="engineDot"></span><span id="engineText">Checking forge…</span></div>
          <span>Free cloud · YouTube</span>
        </div>
      </section>

      <section class="rack" aria-label="Job queue">
        <div class="rack-head">
          <h2>ANVIL RACK</h2>
          <button class="text-btn" id="clear" type="button">Clear finished</button>
        </div>
        <div id="jobs"></div>
      </section>

      <footer class="footer">
        <a href="https://github.com/sbacaro/VidForge" target="_blank" rel="noreferrer">GitHub</a>
        <span>·</span>
        <span>No local companion</span>
      </footer>
    </div>
  </div>
`;P();A();y();c();v();setInterval(()=>{v()},2e4);function P(){const t=document.querySelector("#sparks");if(t)for(let e=0;e<24;e++){const n=document.createElement("span");n.className="spark",n.style.left=`${Math.random()*100}%`,n.style.animationDuration=`${7+Math.random()*10}s`,n.style.animationDelay=`${Math.random()*8}s`,n.style.opacity=String(.25+Math.random()*.5),t.appendChild(n)}}function A(){document.querySelector("#strike")?.addEventListener("click",()=>{h()}),document.querySelector("#url")?.addEventListener("keydown",t=>{t.key==="Enter"&&h()}),document.querySelector("#clear")?.addEventListener("click",()=>{a.jobs=a.jobs.filter(t=>t.phase!=="finished"&&t.phase!=="failed"),c()})}function y(){const t=document.querySelector("#ingots");if(t){t.innerHTML="";for(const e of f){const n=document.createElement("button");n.type="button",n.className="ingot",n.setAttribute("role","radio"),n.setAttribute("aria-checked",e.id===a.selected?"true":"false"),n.innerHTML=`
      <span class="mark">${e.mark}</span>
      <strong>${e.name}</strong>
      <p>${e.blurb}</p>
    `,n.addEventListener("click",()=>{a.selected=e.id,y()}),t.appendChild(n)}}}function c(){const t=document.querySelector("#jobs");if(t){if(!a.jobs.length){t.innerHTML=`
      <div class="empty">
        <strong>The anvil is cold.</strong>
        Paste a YouTube link and strike. Runs entirely in your browser via GitHub Pages.
      </div>
    `;return}t.innerHTML=a.jobs.map(e=>{const n=m(e.alloy),s=e.downloadUrl?`<a href="${H(e.downloadUrl)}" target="_blank" rel="noreferrer">Download</a>`:"";return`
        <article class="job">
          <div class="job-top">
            <div>
              <strong>${p(e.title)}</strong>
              <div class="meta">${p(n.name)}</div>
            </div>
            <div class="phase ${e.phase}">${w(e.phase)}</div>
          </div>
          <div class="heat"><i style="width:${Math.round(e.progress*100)}%"></i></div>
          <div class="job-foot">
            <p>${p(e.status)}</p>
            ${s}
          </div>
        </article>
      `}).join("")}}async function v(){a.online=await S();const t=document.querySelector("#engineDot"),e=document.querySelector("#engineText");t&&(t.classList.toggle("on",a.online),t.classList.toggle("off",!a.online)),e&&(e.textContent=a.online?"Cloud forge ready":"Network offline")}async function h(){const t=document.querySelector("#url"),e=t.value.trim();if(!e||a.busy)return;const n={id:k(),url:e,alloy:a.selected,title:"Unknown ore",phase:"queued",progress:.02,status:"Heating…",createdAt:Date.now()};a.jobs.unshift(n),t.value="",a.busy=!0,document.querySelector("#strike").disabled=!0,c();const s=r=>{Object.assign(n,r),c()};try{await L(n,s)}catch(r){s({phase:"failed",progress:0,status:r instanceof Error?r.message:String(r),error:r instanceof Error?r.message:String(r)})}finally{a.busy=!1,document.querySelector("#strike").disabled=!1,c()}}function p(t){return t.replace(/[&<>"']/g,e=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"})[e])}function H(t){return p(t)}
