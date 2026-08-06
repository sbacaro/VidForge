const alloys = [
  { id: "archive-pure", title: "Archive Pure", desc: "Maximum fidelity · best for keeping", cobalt: { videoQuality: "max", downloadMode: "auto" } },
  { id: "crystal", title: "Crystal", desc: "Near-lossless priority · highest web quality", cobalt: { videoQuality: "max", downloadMode: "auto" } },
  { id: "tempered", title: "Tempered", desc: "Balanced high quality for everyday playback", cobalt: { videoQuality: "1080", downloadMode: "auto" } },
  { id: "audio-ingot", title: "Audio Ingot", desc: "Best audio only", cobalt: { downloadMode: "audio", audioFormat: "best" } },
];

const STORAGE_KEY = "vidforge-web-settings-v1";
const state = {
  selected: "archive-pure",
  jobs: [],
  engine: "auto",
  apiBase: "https://api.cobalt.tools/",
  localOnline: false,
};

function loadSettings() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return;
    const parsed = JSON.parse(raw);
    if (parsed.engine) state.engine = parsed.engine;
    if (parsed.apiBase) state.apiBase = parsed.apiBase;
  } catch (_) {}
}

function saveSettings() {
  localStorage.setItem(
    STORAGE_KEY,
    JSON.stringify({ engine: state.engine, apiBase: state.apiBase })
  );
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])
  );
}

function renderAlloys() {
  const box = document.getElementById("alloys");
  box.innerHTML = "";
  alloys.forEach((a) => {
    const b = document.createElement("button");
    b.type = "button";
    b.className = "alloy" + (a.id === state.selected ? " active" : "");
    b.setAttribute("role", "option");
    b.setAttribute("aria-selected", a.id === state.selected ? "true" : "false");
    b.innerHTML = `<b>${a.title}</b><span>${a.desc}</span>`;
    b.onclick = () => {
      state.selected = a.id;
      renderAlloys();
    };
    box.appendChild(b);
  });
}

function renderJobs() {
  const el = document.getElementById("jobs");
  if (!state.jobs.length) {
    el.innerHTML = '<div class="empty">The anvil is cold.</div>';
    return;
  }
  el.innerHTML = state.jobs
    .map((j) => {
      const cls = j.phase === "finished" ? "done" : j.phase === "failed" ? "fail" : "";
      const action = j.downloadUrl
        ? `<a class="link" href="${escapeHtml(j.downloadUrl)}" target="_blank" rel="noopener">Download</a>`
        : j.output
          ? `<span class="status">${escapeHtml(j.output)}</span>`
          : "";
      return `<div class="job">
        <div class="top">
          <div>
            <strong>${escapeHtml(j.title)}</strong>
            <div class="status">${escapeHtml(j.alloy)}</div>
          </div>
          <div class="phase ${cls}">${escapeHtml(j.phase)}</div>
        </div>
        <div class="bar"><i style="width:${Math.round((j.progress || 0) * 100)}%"></i></div>
        <div class="status">${escapeHtml(j.status || "")}</div>
        ${action}
      </div>`;
    })
    .join("");
}

async function probeLocal() {
  try {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 700);
    const res = await fetch("http://127.0.0.1:8742/api/jobs", { signal: ctrl.signal });
    clearTimeout(t);
    state.localOnline = res.ok;
  } catch (_) {
    state.localOnline = false;
  }
  updateHint();
}

function updateHint() {
  const hint = document.getElementById("engineHint");
  if (state.engine === "local" || (state.engine === "auto" && state.localOnline)) {
    hint.textContent = state.localOnline
      ? "Engine: local VidForge companion (max quality on your Mac)."
      : "Local companion offline. Start it with: vidforge-ui";
    return;
  }
  hint.textContent =
    "Engine: web forge via Cobalt-compatible API. For Archive Pure local remux, run vidforge-ui.";
}

async function forgeLocal(job) {
  const res = await fetch("http://127.0.0.1:8742/api/forge", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ url: job.url, alloy: job.alloy }),
  });
  if (!res.ok) throw new Error("Local companion rejected the job.");
  job.status = "Smelting on local companion…";
  job.progress = 0.2;
  renderJobs();

  // Poll local queue for this URL title updates
  for (let i = 0; i < 600; i++) {
    await sleep(1000);
    const list = await (await fetch("http://127.0.0.1:8742/api/jobs")).json();
    const match =
      list.find((x) => x.id === job.localId) ||
      list.find((x) => x.url === job.url);
    if (!match) continue;
    job.localId = match.id;
    job.title = match.title || job.title;
    job.phase = match.phase;
    job.progress = match.progress || job.progress;
    job.status = match.status || job.status;
    job.output = match.output;
    if (match.phase === "finished" || match.phase === "failed") {
      if (match.phase === "failed") throw new Error(match.error || match.status || "Forge failed");
      job.phase = "finished";
      job.progress = 1;
      job.status = "Forged locally";
      return;
    }
    renderJobs();
  }
  throw new Error("Timed out waiting for local forge.");
}

async function forgeCobalt(job) {
  const alloy = alloys.find((a) => a.id === job.alloy) || alloys[0];
  const base = state.apiBase.endsWith("/") ? state.apiBase : state.apiBase + "/";
  job.status = "Prospecting via web forge…";
  job.progress = 0.15;
  renderJobs();

  const payload = {
    url: job.url,
    filenameStyle: "pretty",
    ...alloy.cobalt,
  };

  const res = await fetch(base, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(data.error?.message || data.text || `Web forge HTTP ${res.status}`);
  }

  if (data.status === "error") {
    throw new Error(data.error?.message || data.text || "Web forge error");
  }

  if (data.status === "picker" && Array.isArray(data.picker) && data.picker.length) {
    const first = data.picker.find((p) => p.type === "video") || data.picker[0];
    job.downloadUrl = first.url;
    job.title = first.filename || job.title;
  } else if (data.url) {
    job.downloadUrl = data.url;
    job.title = data.filename || job.title;
  } else if (data.tunnel) {
    job.downloadUrl = data.tunnel;
  } else {
    throw new Error("Web forge returned no download URL.");
  }

  job.phase = "finished";
  job.progress = 1;
  job.status = "Ready — tap Download";
}

async function strike() {
  const url = document.getElementById("url").value.trim();
  if (!url) return;

  const job = {
    id: crypto.randomUUID(),
    url,
    alloy: state.selected,
    title: "Unknown ore",
    phase: "smelting",
    progress: 0.05,
    status: "Heating the forge…",
  };
  state.jobs.unshift(job);
  document.getElementById("url").value = "";
  renderJobs();

  const btn = document.getElementById("strike");
  btn.disabled = true;
  try {
    await probeLocal();
    const useLocal =
      state.engine === "local" || (state.engine === "auto" && state.localOnline);
    if (useLocal) {
      if (!state.localOnline) throw new Error("Local companion is offline. Run vidforge-ui.");
      await forgeLocal(job);
    } else {
      await forgeCobalt(job);
    }
  } catch (err) {
    job.phase = "failed";
    job.progress = 0;
    job.status = err.message || String(err);
  } finally {
    btn.disabled = false;
    renderJobs();
  }
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function bind() {
  document.getElementById("strike").onclick = strike;
  document.getElementById("settingsBtn").onclick = () => {
    const panel = document.getElementById("settings");
    panel.hidden = !panel.hidden;
  };
  document.getElementById("clearFinished").onclick = () => {
    state.jobs = state.jobs.filter((j) => j.phase !== "finished" && j.phase !== "failed");
    renderJobs();
  };
  document.getElementById("engine").value = state.engine;
  document.getElementById("apiBase").value = state.apiBase;
  document.getElementById("engine").onchange = (e) => {
    state.engine = e.target.value;
    saveSettings();
    updateHint();
  };
  document.getElementById("apiBase").onchange = (e) => {
    state.apiBase = e.target.value.trim() || "https://api.cobalt.tools/";
    saveSettings();
  };
  document.getElementById("url").addEventListener("keydown", (e) => {
    if (e.key === "Enter") strike();
  });
}

loadSettings();
renderAlloys();
renderJobs();
bind();
probeLocal();
setInterval(probeLocal, 5000);
