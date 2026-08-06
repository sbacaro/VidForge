import "./styles.css";
import { ALLOYS } from "./types";
import type { AlloyId, ForgeJob, Settings } from "./types";
import { alloyById, loadSettings, phaseLabel, saveSettings, uid } from "./lib";
import { describeEngineNeed, forgeCustomApi, forgeLocal, pingLocal } from "./engine";

const root = document.querySelector<HTMLDivElement>("#app");
if (!root) {
  throw new Error("#app missing");
}

const state = {
  settings: loadSettings(),
  selected: "archive-pure" as AlloyId,
  jobs: [] as ForgeJob[],
  localOnline: false,
  busy: false,
  settingsOpen: false,
};

root.innerHTML = `
  <div class="stage">
    <div class="glow" aria-hidden="true"></div>
    <div class="sparks" id="sparks" aria-hidden="true"></div>
    <div class="shell">
      <header class="topbar">
        <div class="brand">
          <strong>VIDFORGE</strong>
          <span>Feed a URL. Choose an alloy. Strike.</span>
        </div>
        <button class="icon-btn" id="openSettings" type="button" aria-label="Settings">⚙</button>
      </header>

      <section class="furnace" aria-label="Forge controls">
        <div class="field-label">Ore</div>
        <div class="ore-row">
          <input id="url" type="url" placeholder="https://… paste any supported video link" autocomplete="off" />
          <button class="strike" id="strike" type="button">Strike</button>
        </div>

        <div class="field-label">Alloy</div>
        <div class="ingots" id="ingots" role="radiogroup" aria-label="Alloy"></div>

        <div class="statusline">
          <div class="pill"><span class="dot" id="engineDot"></span><span id="engineText">Checking forge…</span></div>
          <span id="hint">GitHub Pages is the UI. Your Mac runs the fire.</span>
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
        <a href="https://github.com/sbacaro/VidForge#install-mac-companion-no-xcode" target="_blank" rel="noreferrer">Install companion</a>
      </footer>
    </div>

    <div class="drawer" id="drawer" hidden>
      <div class="drawer-panel" role="dialog" aria-modal="true" aria-labelledby="settingsTitle">
        <h3 id="settingsTitle">SETTINGS</h3>
        <label>
          Engine
          <select id="engine">
            <option value="local">Local companion (recommended)</option>
            <option value="custom-api">Custom Cobalt-compatible API</option>
          </select>
        </label>
        <label>
          Local companion URL
          <input id="localBase" type="url" />
        </label>
        <label>
          Custom API base
          <input id="apiBase" type="url" placeholder="https://your-cobalt-instance.example" />
        </label>
        <label>
          API key (optional)
          <input id="apiKey" type="password" autocomplete="off" placeholder="Api-Key token" />
        </label>
        <p class="meta">
          Official api.cobalt.tools requires JWT and is not for third-party apps.
          Use the local companion, or your own API instance.
        </p>
        <div class="drawer-actions">
          <button class="ghost" id="closeSettings" type="button">Close</button>
          <button class="strike" id="saveSettings" type="button">Save</button>
        </div>
      </div>
    </div>
  </div>
`;

seedSparks();
bind();
renderIngots();
renderJobs();
syncSettingsForm();
refreshEngine();
setInterval(refreshEngine, 4000);

function seedSparks(): void {
  const host = document.querySelector("#sparks");
  if (!host) return;
  for (let i = 0; i < 24; i++) {
    const s = document.createElement("span");
    s.className = "spark";
    s.style.left = `${Math.random() * 100}%`;
    s.style.animationDuration = `${7 + Math.random() * 10}s`;
    s.style.animationDelay = `${Math.random() * 8}s`;
    s.style.opacity = String(0.25 + Math.random() * 0.5);
    host.appendChild(s);
  }
}

function bind(): void {
  document.querySelector("#strike")?.addEventListener("click", () => void strike());
  document.querySelector("#url")?.addEventListener("keydown", (e) => {
    if ((e as KeyboardEvent).key === "Enter") void strike();
  });
  document.querySelector("#clear")?.addEventListener("click", () => {
    state.jobs = state.jobs.filter((j) => j.phase !== "finished" && j.phase !== "failed");
    renderJobs();
  });
  document.querySelector("#openSettings")?.addEventListener("click", () => {
    state.settingsOpen = true;
    syncSettingsForm();
    document.querySelector("#drawer")?.removeAttribute("hidden");
  });
  document.querySelector("#closeSettings")?.addEventListener("click", closeSettings);
  document.querySelector("#drawer")?.addEventListener("click", (e) => {
    if (e.target === document.querySelector("#drawer")) closeSettings();
  });
  document.querySelector("#saveSettings")?.addEventListener("click", () => {
    const engine = (document.querySelector("#engine") as HTMLSelectElement).value as Settings["engine"];
    const localBase = (document.querySelector("#localBase") as HTMLInputElement).value.trim();
    const apiBase = (document.querySelector("#apiBase") as HTMLInputElement).value.trim();
    const apiKey = (document.querySelector("#apiKey") as HTMLInputElement).value.trim();
    state.settings = { engine, localBase, apiBase, apiKey };
    saveSettings(state.settings);
    closeSettings();
    void refreshEngine();
  });
}

function closeSettings(): void {
  state.settingsOpen = false;
  document.querySelector("#drawer")?.setAttribute("hidden", "");
}

function syncSettingsForm(): void {
  (document.querySelector("#engine") as HTMLSelectElement).value = state.settings.engine;
  (document.querySelector("#localBase") as HTMLInputElement).value = state.settings.localBase;
  (document.querySelector("#apiBase") as HTMLInputElement).value = state.settings.apiBase;
  (document.querySelector("#apiKey") as HTMLInputElement).value = state.settings.apiKey;
}

function renderIngots(): void {
  const host = document.querySelector("#ingots");
  if (!host) return;
  host.innerHTML = "";
  for (const alloy of ALLOYS) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "ingot";
    btn.setAttribute("role", "radio");
    btn.setAttribute("aria-checked", alloy.id === state.selected ? "true" : "false");
    btn.innerHTML = `
      <span class="mark">${alloy.mark}</span>
      <strong>${alloy.name}</strong>
      <p>${alloy.blurb}</p>
    `;
    btn.addEventListener("click", () => {
      state.selected = alloy.id;
      renderIngots();
    });
    host.appendChild(btn);
  }
}

function renderJobs(): void {
  const host = document.querySelector("#jobs");
  if (!host) return;

  if (!state.jobs.length) {
    host.innerHTML = `
      <div class="empty">
        <strong>The anvil is cold.</strong>
        Drop a link above. For max quality, keep <code>vidforge-ui</code> running on this Mac.
      </div>
    `;
    return;
  }

  host.innerHTML = state.jobs
    .map((job) => {
      const alloy = alloyById(job.alloy);
      const action = job.downloadUrl
        ? `<a href="${escapeAttr(job.downloadUrl)}" target="_blank" rel="noreferrer">Download</a>`
        : job.outputPath
          ? `<span class="meta">${escapeHtml(job.outputPath)}</span>`
          : "";
      return `
        <article class="job">
          <div class="job-top">
            <div>
              <strong>${escapeHtml(job.title)}</strong>
              <div class="meta">${escapeHtml(alloy.name)}</div>
            </div>
            <div class="phase ${job.phase}">${phaseLabel(job.phase)}</div>
          </div>
          <div class="heat"><i style="width:${Math.round(job.progress * 100)}%"></i></div>
          <div class="job-foot">
            <p>${escapeHtml(job.status)}</p>
            ${action}
          </div>
        </article>
      `;
    })
    .join("");
}

async function refreshEngine(): Promise<void> {
  state.localOnline = await pingLocal(state.settings.localBase);
  const dot = document.querySelector("#engineDot");
  const text = document.querySelector("#engineText");
  const hint = document.querySelector("#hint");
  if (dot) {
    dot.classList.toggle("on", state.localOnline);
    dot.classList.toggle("off", !state.localOnline && state.settings.engine === "local");
  }
  if (text) {
    text.textContent = describeEngineNeed(state.settings.engine, state.localOnline);
  }
  if (hint) {
    hint.textContent =
      state.settings.engine === "local"
        ? "Pages = remote control. Companion = yt-dlp + ffmpeg on your machine."
        : "Bring your own Cobalt-compatible instance. Official Cobalt JWT is not supported.";
  }
}

async function strike(): Promise<void> {
  const input = document.querySelector("#url") as HTMLInputElement;
  const url = input.value.trim();
  if (!url || state.busy) return;

  const job: ForgeJob = {
    id: uid(),
    url,
    alloy: state.selected,
    title: "Unknown ore",
    phase: "queued",
    progress: 0.02,
    status: "Heating…",
    createdAt: Date.now(),
  };

  state.jobs.unshift(job);
  input.value = "";
  state.busy = true;
  (document.querySelector("#strike") as HTMLButtonElement).disabled = true;
  renderJobs();

  const patch = (p: Partial<ForgeJob>) => {
    Object.assign(job, p);
    renderJobs();
  };

  try {
    await refreshEngine();
    if (state.settings.engine === "local") {
      if (!state.localOnline) {
        throw new Error("Local companion offline. In Terminal: export PATH=\"$HOME/.local/bin:$PATH\" && vidforge-ui");
      }
      await forgeLocal(state.settings, job, patch);
    } else {
      await forgeCustomApi(state.settings, job, patch);
    }
  } catch (err) {
    patch({
      phase: "failed",
      progress: 0,
      status: err instanceof Error ? err.message : String(err),
      error: err instanceof Error ? err.message : String(err),
    });
  } finally {
    state.busy = false;
    (document.querySelector("#strike") as HTMLButtonElement).disabled = false;
    renderJobs();
  }
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!
  );
}

function escapeAttr(value: string): string {
  return escapeHtml(value);
}
