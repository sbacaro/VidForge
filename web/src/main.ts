import "./styles.css";
import { ALLOYS } from "./types";
import type { AlloyId, ForgeJob } from "./types";
import { alloyById, phaseLabel, uid } from "./lib";
import { forgeCloud, pingCloud } from "./engine";

const root = document.querySelector<HTMLDivElement>("#app");
if (!root) throw new Error("#app missing");

const state = {
  selected: "archive-pure" as AlloyId,
  jobs: [] as ForgeJob[],
  online: false,
  busy: false,
};

root.innerHTML = `
  <div class="stage">
    <div class="glow" aria-hidden="true"></div>
    <div class="sparks" id="sparks" aria-hidden="true"></div>
    <div class="shell">
      <header class="topbar">
        <div class="brand">
          <strong>VIDFORGE</strong>
          <span>GitHub Pages UI · Cloudflare forge · nothing to install · v4</span>
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
          <span>Worker API · YouTube</span>
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
`;

seedSparks();
bind();
renderIngots();
renderJobs();
void refreshEngine();
setInterval(() => void refreshEngine(), 20000);

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
        Paste a YouTube link and strike. Runs entirely in your browser via GitHub Pages.
      </div>
    `;
    return;
  }

  host.innerHTML = state.jobs
    .map((job) => {
      const alloy = alloyById(job.alloy);
      const action = job.downloadUrl
        ? `<a href="${escapeAttr(job.downloadUrl)}" target="_blank" rel="noreferrer">Download</a>`
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
  state.online = await pingCloud();
  const dot = document.querySelector("#engineDot");
  const text = document.querySelector("#engineText");
  if (dot) {
    dot.classList.toggle("on", state.online);
    dot.classList.toggle("off", !state.online);
  }
  if (text) {
    text.textContent = state.online ? "Cloud forge ready" : "Cloud forge offline";
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
    await forgeCloud(job, patch);
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
