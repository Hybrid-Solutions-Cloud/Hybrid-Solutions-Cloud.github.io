"use client";

import { useMemo, useState } from "react";

type Project = {
  number: string;
  name: string;
  eyebrow: string;
  description: string;
  status: "Active" | "Preview" | "In the lab";
  category: "Cloud ops" | "AI & automation" | "Security" | "Productivity";
  tags: string[];
  site: string;
  repo: string;
  accent: string;
  featured?: boolean;
};

const projects: Project[] = [
  {
    number: "01",
    name: "AzureScout",
    eyebrow: "See everything. Own your cloud.",
    description:
      "Inventory Azure and Entra ID, assess against CAF and WAF, and turn a sprawling tenant into a self-contained report you can actually use.",
    status: "Active",
    category: "Cloud ops",
    tags: ["PowerShell", "Azure", "Assessment"],
    site: "/azure-scout/",
    repo: "https://github.com/Hybrid-Solutions-Cloud/azure-scout",
    accent: "cyan",
    featured: true,
  },
  {
    number: "02",
    name: "Homestead Foundry",
    eyebrow: "Build AI infrastructure with receipts.",
    description:
      "An open knowledge and automation center for Azure AI Foundry—from model decisions and infrastructure as code to deployment and verification.",
    status: "Active",
    category: "AI & automation",
    tags: ["Azure AI", "Bicep", "Agents"],
    site: "/homestead-foundry/",
    repo: "https://github.com/Hybrid-Solutions-Cloud/homestead-foundry",
    accent: "violet",
    featured: true,
  },
  {
    number: "03",
    name: "Vault Prospector",
    eyebrow: "Find the vault. Protect the secret.",
    description:
      "A local-first Windows desktop app for discovering and searching Azure Key Vault metadata across identities, tenants, and subscriptions.",
    status: "Preview",
    category: "Security",
    tags: ["Windows", "Key Vault", "Local-first"],
    site: "/vault-prospector/",
    repo: "https://github.com/Hybrid-Solutions-Cloud/vault-prospector",
    accent: "amber",
  },
  {
    number: "04",
    name: "Project Marvin",
    eyebrow: "Calendar sprawl, reluctantly solved.",
    description:
      "One mildly resentful product path for onboarding, managing, and automatically syncing the calendars the universe insists on scattering everywhere.",
    status: "In the lab",
    category: "Productivity",
    tags: ["JavaScript", "Calendars", "Azure"],
    site: "/project-marvin/",
    repo: "https://github.com/Hybrid-Solutions-Cloud/project-marvin",
    accent: "lime",
  },
  {
    number: "05",
    name: "Hybrid Infrastructure Toolkit",
    eyebrow: "Build the lab. Rebuild it on purpose.",
    description:
      "Reusable patterns and automation for repeatable hybrid infrastructure labs, from Azure foundations and nested Hyper-V to cluster services and demo-day operations.",
    status: "Active",
    category: "Cloud ops",
    tags: ["PowerShell", "Azure", "Hyper-V"],
    site: "/hybrid-infra-toolkit/",
    repo: "https://github.com/Hybrid-Solutions-Cloud/hybrid-infra-toolkit",
    accent: "cyan",
  },
  {
    number: "06",
    name: "Azure Monitor ITSM",
    eyebrow: "Alerts in. Incidents out. No mystery glue.",
    description:
      "A repeatable Azure Monitor-to-ServiceNow integration built with Logic Apps, managed identity, Key Vault, and infrastructure-as-code deployment options.",
    status: "Active",
    category: "Cloud ops",
    tags: ["Azure Monitor", "ServiceNow", "Logic Apps"],
    site: "/azure-monitor-itsm/",
    repo: "https://github.com/Hybrid-Solutions-Cloud/azure-monitor-itsm",
    accent: "violet",
  },
];

const filters = [
  "All",
  "Cloud ops",
  "AI & automation",
  "Security",
  "Productivity",
] as const;

export function ProjectCatalog() {
  const [activeFilter, setActiveFilter] = useState<(typeof filters)[number]>(
    "All",
  );

  const visibleProjects = useMemo(
    () =>
      activeFilter === "All"
        ? projects
        : projects.filter((project) => project.category === activeFilter),
    [activeFilter],
  );

  return (
    <main>
      <header className="site-header">
        <a className="brand" href="#top" aria-label="Hybrid Solutions Cloud Labs home">
          <span className="brand-mark" aria-hidden="true">
            <span />
            <span />
            <span />
          </span>
          <span className="brand-name">
            Hybrid Solutions Cloud <strong>Labs</strong>
          </span>
        </a>

        <nav aria-label="Primary navigation">
          <a href="#projects">Projects</a>
          <a href="#about">About</a>
          <a
            className="nav-github"
            href="https://github.com/Hybrid-Solutions-Cloud"
            target="_blank"
            rel="noreferrer"
          >
            GitHub <span aria-hidden="true">↗</span>
          </a>
        </nav>
      </header>

      <section className="hero" id="top">
        <div className="hero-grid" aria-hidden="true" />
        <div className="hero-orbit orbit-one" aria-hidden="true" />
        <div className="hero-orbit orbit-two" aria-hidden="true" />

        <div className="hero-copy">
          <p className="kicker">
            <span className="pulse" aria-hidden="true" /> Independent cloud tools
            &amp; experiments
          </p>
          <h1>
            Useful things,
            <br />
            built <em>out loud.</em>
          </h1>
          <p className="hero-intro">
            A working catalog of cloud tools, AI infrastructure, security software,
            and side quests from Hybrid Solutions Cloud. Some are shipped. Some are
            stubbornly becoming real.
          </p>
          <div className="hero-actions">
            <a className="button button-primary" href="#projects">
              Explore the work <span aria-hidden="true">↓</span>
            </a>
            <a
              className="button button-ghost"
              href="https://github.com/Hybrid-Solutions-Cloud"
              target="_blank"
              rel="noreferrer"
            >
              View the organization <span aria-hidden="true">↗</span>
            </a>
          </div>
        </div>

        <aside className="lab-console" aria-label="Lab status">
          <div className="console-topline">
            <span>LAB_STATUS.LOG</span>
            <span className="console-live">LIVE</span>
          </div>
          <div className="console-body">
            <p><span>01</span> catalog.public_projects <b>6</b></p>
            <p><span>02</span> build.current_state <b>IN_PROGRESS</b></p>
            <p><span>03</span> ideas.open_tabs <b>TOO_MANY</b></p>
            <p><span>04</span> perfection.required <b>FALSE</b></p>
          </div>
          <div className="console-signal" aria-hidden="true">
            {Array.from({ length: 24 }, (_, index) => (
              <i key={index} style={{ height: `${18 + ((index * 13) % 52)}%` }} />
            ))}
          </div>
          <p className="console-caption">Last known good idea: probably five minutes ago.</p>
        </aside>
      </section>

      <section className="manifesto-strip" aria-label="Lab principles">
        <p><span>BUILD</span> the useful thing</p>
        <i aria-hidden="true">✦</i>
        <p><span>SHOW</span> the real work</p>
        <i aria-hidden="true">✦</i>
        <p><span>SHIP</span> before perfect</p>
      </section>

      <section className="projects-section" id="projects">
        <div className="section-heading">
          <div>
            <p className="section-index">01 / PROJECT CATALOG</p>
            <h2>Currently on the bench</h2>
          </div>
          <p>
            Public projects only. Status labels are honest, links are live, and
            nothing has been quietly declared “done” just to make the grid look tidy.
          </p>
        </div>

        <div className="filter-bar" aria-label="Filter projects">
          {filters.map((filter) => (
            <button
              type="button"
              key={filter}
              className={activeFilter === filter ? "active" : ""}
              aria-pressed={activeFilter === filter}
              onClick={() => setActiveFilter(filter)}
            >
              {filter}
            </button>
          ))}
        </div>

        <div className="project-grid" aria-live="polite">
          {visibleProjects.map((project) => (
            <article
              className={`project-card accent-${project.accent} ${project.featured ? "featured" : ""}`}
              key={project.name}
            >
              <div className="card-topline">
                <span className="project-number">{project.number}</span>
                <span className={`status status-${project.status.toLowerCase().replaceAll(" ", "-")}`}>
                  <i aria-hidden="true" /> {project.status}
                </span>
              </div>
              <div className="project-glyph" aria-hidden="true">
                <span>{project.name.slice(0, 2).toUpperCase()}</span>
              </div>
              <div className="card-copy">
                <p className="project-eyebrow">{project.eyebrow}</p>
                <h3>{project.name}</h3>
                <p className="project-description">{project.description}</p>
              </div>
              <ul className="tag-list" aria-label={`${project.name} technologies`}>
                {project.tags.map((tag) => <li key={tag}>{tag}</li>)}
              </ul>
              <div className="card-links">
                <a className="project-link" href={project.site}>
                  Open project <span aria-hidden="true">→</span>
                </a>
                <a href={project.repo} target="_blank" rel="noreferrer">
                  Source <span className="sr-only">for {project.name}</span>
                  <span aria-hidden="true">↗</span>
                </a>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="about-section" id="about">
        <div className="about-label">
          <p className="section-index">02 / WHY LABS</p>
          <span aria-hidden="true">HSC—LABS / 2026</span>
        </div>
        <div className="about-copy">
          <h2>Built because the problem was annoying enough.</h2>
          <p>
            Hybrid Solutions Cloud Labs is the public workbench behind the ideas:
            practical software for cloud operators, builders, and anyone who would
            rather automate the tedious part. It is maintained by Kristopher Turner,
            one useful rabbit hole at a time.
          </p>
          <a href="https://hybridsolutions.cloud" target="_blank" rel="noreferrer">
            Visit Hybrid Solutions Cloud LLC <span aria-hidden="true">↗</span>
          </a>
        </div>
        <div className="about-stamp" aria-hidden="true">
          <span>OPEN</span>
          <strong>LAB</strong>
          <small>EST. WHENEVER THE IDEA HIT</small>
        </div>
      </section>

      <footer>
        <a className="brand footer-brand" href="#top">
          <span className="brand-mark" aria-hidden="true"><span /><span /><span /></span>
          <span className="brand-name">HSC <strong>Labs</strong></span>
        </a>
        <p>Experiments welcome. Buzzwords require evidence.</p>
        <div>
          <a href="https://github.com/Hybrid-Solutions-Cloud" target="_blank" rel="noreferrer">GitHub ↗</a>
          <a href="https://hybridsolutions.cloud" target="_blank" rel="noreferrer">LLC site ↗</a>
        </div>
      </footer>
    </main>
  );
}
