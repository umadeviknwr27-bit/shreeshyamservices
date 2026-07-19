/* Shree Shyam Services — shared JS
   Pattern: renderNav()/renderFooter() injected into #nav-root / #footer-root on every page,
   same convention used on ZoomFly (main.js). Keeps every page thin.
*/

// ---------------------------------------------------------------
// 1. SUPABASE CONFIG — replace with your project's values.
//    Find these in Supabase Dashboard > Project Settings > API
// ---------------------------------------------------------------
const SUPABASE_URL = "https://yyhjtynqjrcodnnzlkfm.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl5aGp0eW5xanJjb2Rubnpsa2ZtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM1NTY4OTYsImV4cCI6MjA5OTEzMjg5Nn0.-JxwpNg8_Fx5523hLpZayXt7tl2-oAI_EkF0PgHdzX8";

// Loaded via CDN script tag in each page (see <head>), exposes window.supabase
let sb = null;
function getClient() {
  if (!sb && window.supabase) {
    sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  }
  return sb;
}

// ---------------------------------------------------------------
// 2. BUSINESS INFO — defaults, overwritten at runtime from the
//    `page_content` table (page_key = 'business_info') so it's editable
//    from admin. These hardcoded values are only the fallback shown
//    before that fetch resolves, or if Supabase is unreachable.
// ---------------------------------------------------------------
const BUSINESS = {
  name: "Shree Shyam Services",
  phones: ["+91 9599459187", "+91 7011509629"],
  whatsapp: "919599459187", // primary, no + or spaces, for wa.me links
  address: "B1/46 Bharat Vihar, Kakrola, near Deepika International School, Sector 14, Dwarka, New Delhi",
  hours: "10:00 AM – 10:00 PM, All 7 days",
  social: { facebook: "", instagram: "", youtube: "", google: "" }, // empty = icon hidden
};

// Logo/favicon — set from admin (Branding tab), stored in site_settings.
// Empty = fall back to the text-based "SS" badge and no custom favicon.
const BRANDING = { logo_url: "", favicon_url: "" };

async function loadBranding() {
  try {
    const client = getClient();
    if (!client) return;
    const { data, error } = await client.from("site_settings").select("logo_url, favicon_url").eq("id", 1).single();
    if (error || !data) return;
    BRANDING.logo_url = data.logo_url || "";
    BRANDING.favicon_url = data.favicon_url || "";
    if (BRANDING.favicon_url) {
      let link = document.querySelector("link[rel='icon']");
      if (!link) {
        link = document.createElement("link");
        link.rel = "icon";
        document.head.appendChild(link);
      }
      link.href = BRANDING.favicon_url;
    }
  } catch (err) {
    console.error(err);
  }
}

// ---------------------------------------------------------------
// 2.5. GENERIC CONTENT SYSTEM — every page's editable text lives in the
//      `page_content` table as {page_key, content: {key: value}}. Any
//      element with data-ck="some_key" gets its innerHTML replaced by
//      content.some_key once loaded. This is generic on purpose: adding
//      a new editable field anywhere just means adding a data-ck attribute
//      in the HTML and a matching key in Supabase — no code changes needed.
// ---------------------------------------------------------------
async function loadBusinessInfo() {
  try {
    const client = getClient();
    if (!client) return;
    const { data, error } = await client.from("page_content").select("content").eq("page_key", "business_info").single();
    if (error || !data || !data.content) return;
    const c = data.content;
    if (c.name) BUSINESS.name = c.name;
    if (c.phone_1 || c.phone_2) BUSINESS.phones = [c.phone_1 || BUSINESS.phones[0], c.phone_2 || BUSINESS.phones[1]];
    if (c.whatsapp) BUSINESS.whatsapp = c.whatsapp;
    if (c.address) BUSINESS.address = c.address;
    if (c.hours) BUSINESS.hours = c.hours;
    BUSINESS.social = {
      facebook: c.facebook_url || "",
      instagram: c.instagram_url || "",
      youtube: c.youtube_url || "",
      google: c.google_url || "",
    };
  } catch (err) {
    console.error(err);
  }
}

async function applyPageContent(pageKey) {
  try {
    const client = getClient();
    if (!client) return;
    const { data, error } = await client.from("page_content").select("content").eq("page_key", pageKey).single();
    if (error || !data || !data.content) return;
    Object.entries(data.content).forEach(([key, value]) => {
      document.querySelectorAll(`[data-ck="${key}"]`).forEach(el => { el.innerHTML = value; });
    });
  } catch (err) {
    console.error(err);
  }
}

// ---------------------------------------------------------------
// 2.6. PAGE BOOTSTRAP — replaces the old "renderNav(); renderFooter();"
//      calls at the bottom of each page with one call that also loads
//      business info, page content, and the map where needed.
//      Usage: <script>initSite({ activePage: 'home', pageKey: 'home', map: true });</script>
// ---------------------------------------------------------------
async function initSite(opts = {}) {
  const { activePage = "", pageKey = null, map = false, testimonials = false, pricing = null } = opts;
  await loadBusinessInfo();
  await loadBranding();
  renderNav(activePage);
  renderFooter();
  applyContactLinks();
  if (pageKey) applyPageContent(pageKey);
  if (map) renderMap("map-root");
  if (testimonials) renderTestimonials("testimonials-root");
  if (pricing) renderPricingItems(pricing.containerId, pricing);
}

// ---------------------------------------------------------------
// 2.7. CONTACT LINKS — any WhatsApp/phone link elsewhere on a page
//      (hero CTAs, service pages, pay page, etc.) can opt into staying
//      in sync with the business_info CMS record by adding:
//        data-wa-link            -> WhatsApp link, default greeting
//        data-wa-link="Custom message"  -> WhatsApp link, custom greeting
//        data-tel-link="0"       -> tel: link to phones[0] (primary)
//        data-tel-link="1"       -> tel: link to phones[1] (secondary)
//        data-tel-link-text      -> (add alongside data-tel-link) also
//                                   replaces the link's visible text
//      The href in the HTML source is just a static fallback in case
//      Supabase is unreachable or JS fails to load.
// ---------------------------------------------------------------
function applyContactLinks() {
  document.querySelectorAll("[data-wa-link]").forEach(el => {
    const custom = el.getAttribute("data-wa-link");
    const text = custom && custom.trim() ? custom : "Hi, I need help with an appliance repair.";
    el.href = `https://wa.me/${BUSINESS.whatsapp}?text=${encodeURIComponent(text)}`;
  });
  document.querySelectorAll("[data-tel-link]").forEach(el => {
    const idx = parseInt(el.getAttribute("data-tel-link"), 10) || 0;
    const phone = BUSINESS.phones[idx] || BUSINESS.phones[0];
    el.href = `tel:${phone.replace(/\s/g, "")}`;
    if (el.hasAttribute("data-tel-link-text")) el.textContent = phone;
  });
}

// ---------------------------------------------------------------
// PRICING ITEMS — single source of truth for every price shown on
// the site. Admin manages these once in /admin (Pricing tab); the
// homepage teaser, each service page, and /pricing.html all render
// from this same table so a price only ever needs updating in one
// place. See supabase/pricing-items-only.sql for the table.
// ---------------------------------------------------------------
function renderPriceCard(item) {
  return `
    <div class="card card-price">
      <div class="unit">${escHtml(item.item_label)}</div>
      <div class="amount">${escHtml(item.price_text)}</div>
      ${item.description ? `<p style="font-size:0.85rem;color:var(--ink-soft);">${escHtml(item.description)}</p>` : ""}
    </div>
  `;
}

// For pages with a richer custom layout per price (e.g. AMC's bullet lists)
// that can't just use a generic card grid, this fills specific label/amount
// element IDs in order from the matching service_page's pricing_items.
async function fillPricingSlots(servicePage, slots) {
  try {
    const client = getClient();
    if (!client) throw new Error("not configured");
    const { data, error } = await client
      .from("pricing_items")
      .select("*")
      .eq("service_page", servicePage)
      .order("sort_order", { ascending: true });
    if (error) throw error;
    (data || []).forEach((item, i) => {
      if (!slots[i]) return;
      const labelEl = document.getElementById(slots[i].labelId);
      const amountEl = document.getElementById(slots[i].amountId);
      if (labelEl) labelEl.textContent = item.item_label;
      if (amountEl) amountEl.textContent = item.price_text;
    });
  } catch (err) {
    console.error(err);
  }
}

async function renderPricingItems(containerId, opts = {}) {
  const root = document.getElementById(containerId);
  if (!root) return;
  try {
    const client = getClient();
    if (!client) throw new Error("not configured");
    let query = client.from("pricing_items").select("*").order("category", { ascending: true }).order("sort_order", { ascending: true });
    if (opts.servicePage) query = query.eq("service_page", opts.servicePage);
    if (opts.homepageOnly) query = query.eq("show_on_homepage", true);
    const { data, error } = await query;
    if (error) throw error;
    let items = data || [];
    if (opts.limit) items = items.slice(0, opts.limit);
    if (items.length === 0) return;

    if (opts.groupByCategory) {
      const categories = [];
      const byCat = {};
      items.forEach(it => {
        if (!byCat[it.category]) { byCat[it.category] = []; categories.push(it.category); }
        byCat[it.category].push(it);
      });
      root.innerHTML = categories.map((cat, i) => `
        <section class="section${i % 2 === 1 ? " section-dim" : ""}">
          <div class="container">
            <h2>${escHtml(cat)}</h2>
            <div class="grid grid-3">${byCat[cat].map(renderPriceCard).join("")}</div>
          </div>
        </section>
      `).join("");
    } else {
      root.innerHTML = items.map(renderPriceCard).join("");
    }
  } catch (err) {
    console.error(err);
  }
}

// ---------------------------------------------------------------
// TESTIMONIALS — public read-only display of admin-managed customer
// reviews. Section is hidden entirely if there are no published
// testimonials yet, rather than showing an empty/awkward block.
// ---------------------------------------------------------------
function escHtml(str) {
  const d = document.createElement("div");
  d.textContent = str == null ? "" : str;
  return d.innerHTML;
}

async function renderTestimonials(containerId) {
  const root = document.getElementById(containerId);
  if (!root) return;
  const section = root.closest("section");
  try {
    const client = getClient();
    if (!client) throw new Error("not configured");
    const { data, error } = await client
      .from("testimonials")
      .select("*")
      .eq("is_published", true)
      .order("sort_order", { ascending: true })
      .order("created_at", { ascending: false });
    if (error) throw error;
    if (!data || data.length === 0) {
      if (section) section.style.display = "none";
      return;
    }
    root.innerHTML = data.map(t => `
      <div class="card testimonial-card">
        <div class="stars" aria-label="${t.rating || 5} out of 5 stars">${"★".repeat(t.rating || 5)}${"☆".repeat(5 - (t.rating || 5))}</div>
        <p class="testimonial-quote">&ldquo;${escHtml(t.quote)}&rdquo;</p>
        <div class="testimonial-name">${escHtml(t.customer_name)}${t.service_type ? " · " + escHtml(t.service_type) : ""}</div>
      </div>
    `).join("");
  } catch (err) {
    if (section) section.style.display = "none";
    console.error(err);
  }
}

// ---------------------------------------------------------------
// 3.5. OFFICE MAP — location is managed from /admin (site_settings table),
//      not hardcoded here, so it can be updated without touching code.
// ---------------------------------------------------------------
async function renderMap(containerId) {
  const root = document.getElementById(containerId);
  if (!root) return;
  root.innerHTML = `<p style="color:var(--ink-soft);">Loading map...</p>`;

  try {
    const client = getClient();
    if (!client) throw new Error("not configured");
    const { data, error } = await client.from("site_settings").select("*").eq("id", 1).single();
    if (error) throw error;

    const { latitude, longitude, business_address } = data;
    if (latitude == null || longitude == null) {
      root.innerHTML = `<p style="color:var(--ink-soft);">${business_address || BUSINESS.address}</p>`;
      return;
    }

    const embedSrc = `https://www.google.com/maps?q=${latitude},${longitude}&z=15&output=embed`;
    const directionsHref = `https://www.google.com/maps/dir/?api=1&destination=${latitude},${longitude}`;

    root.innerHTML = `
      <div style="border:1px solid var(--line);border-radius:6px;overflow:hidden;">
        <iframe
          src="${embedSrc}"
          width="100%"
          height="320"
          style="border:0;display:block;"
          loading="lazy"
          referrerpolicy="no-referrer-when-downgrade"
          title="Shree Shyam Services office location">
        </iframe>
      </div>
      <p style="margin:12px 0 0;color:var(--ink-soft);">${business_address || BUSINESS.address}</p>
      <a href="${directionsHref}" target="_blank" rel="noopener" class="btn btn-outline" style="margin-top:8px;display:inline-flex;">Get Directions</a>
    `;
  } catch (err) {
    // Fall back to plain text address if the map/settings can't be loaded
    root.innerHTML = `<p style="color:var(--ink-soft);">${BUSINESS.address}</p>`;
    console.error(err);
  }
}

// ---------------------------------------------------------------
// 4. NAV
// ---------------------------------------------------------------
function renderNav(activePage = "") {
  const root = document.getElementById("nav-root");
  if (!root) return;
  const wa = `https://wa.me/${BUSINESS.whatsapp}?text=${encodeURIComponent("Hi, I need help with an appliance repair.")}`;
  const brandMarkHtml = BRANDING.logo_url
    ? `<img src="${BRANDING.logo_url}" alt="${BUSINESS.name} logo" style="width:40px;height:40px;border-radius:10px;object-fit:cover;">`
    : `<span class="brand-mark">SS</span>`;
  root.innerHTML = `
  <header class="site-header">
    <div class="topbar">
      <div class="container">
        <div class="topbar-links">
          <a href="tel:${BUSINESS.phones[0].replace(/\s/g,'')}">📞 ${BUSINESS.phones[0]}</a>
          <span>Open ${BUSINESS.hours}</span>
        </div>
        <div class="topbar-links">
          <a href="/areas-we-serve.html">Dwarka &amp; West Delhi</a>
          ${topbarSocialIconsHtml()}
        </div>
      </div>
    </div>
    <nav class="container navwrap">
      <a href="/index.html" class="brand">
        ${brandMarkHtml}
        <span class="brand-text">Shree Shyam Services<span>Appliance Repair &amp; AMC</span></span>
      </a>
      <button type="button" class="nav-toggle" id="nav-toggle" aria-label="Open menu" aria-expanded="false" aria-controls="nav-links">☰</button>
      <ul class="nav-links" id="nav-links">
        <li><a href="/index.html" ${activePage==='home'?'class="active"':''}>Home</a></li>
        <li><a href="/about.html" ${activePage==='about'?'class="active"':''}>About</a></li>
        <li><a href="/services/index.html" ${activePage==='services'?'class="active"':''}>Services</a></li>
        <li><a href="/pricing.html" ${activePage==='pricing'?'class="active"':''}>Pricing</a></li>
        <li><a href="/areas-we-serve.html" ${activePage==='areas'?'class="active"':''}>Areas We Serve</a></li>
        <li><a href="/contact.html" ${activePage==='contact'?'class="active"':''}>Contact</a></li>
      </ul>
      <div class="nav-cta">
        <a href="${wa}" data-wa-link class="btn btn-wa" style="padding:9px 16px;font-size:0.88rem;">WhatsApp</a>
        <a href="/pay.html" class="btn btn-outline-gold" style="padding:9px 16px;font-size:0.88rem;">Pay Now</a>
        <a href="/book-service.html" class="btn btn-navy" style="padding:9px 18px;font-size:0.88rem;">Book Service</a>
      </div>
    </nav>
  </header>`;

  const toggleBtn = document.getElementById("nav-toggle");
  const navLinks = document.getElementById("nav-links");
  if (toggleBtn && navLinks) {
    toggleBtn.addEventListener("click", () => {
      const isOpen = navLinks.classList.toggle("open");
      toggleBtn.setAttribute("aria-expanded", isOpen ? "true" : "false");
      toggleBtn.textContent = isOpen ? "✕" : "☰";
    });
    // Close the menu automatically once a link is tapped
    navLinks.querySelectorAll("a").forEach(a => {
      a.addEventListener("click", () => {
        navLinks.classList.remove("open");
        toggleBtn.setAttribute("aria-expanded", "false");
        toggleBtn.textContent = "☰";
      });
    });
  }
}

// ---------------------------------------------------------------
// 5. FOOTER
// ---------------------------------------------------------------
const SOCIAL_ICONS = {
  facebook: `<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><path d="M13.5 21v-8h2.7l.4-3.1h-3.1V8c0-.9.25-1.5 1.55-1.5H16.7V3.7c-.28-.04-1.24-.12-2.36-.12-2.33 0-3.93 1.42-3.93 4.03V10H7.7v3.1h2.7V21h3.1z"/></svg>`,
  instagram: `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3.5" y="3.5" width="17" height="17" rx="4.5"/><circle cx="12" cy="12" r="3.7"/><circle cx="17.2" cy="6.8" r="1" fill="currentColor" stroke="none"/></svg>`,
  youtube: `<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><path d="M22 12s0-3.2-.4-4.7c-.24-.9-.94-1.6-1.83-1.84C18.2 5 12 5 12 5s-6.2 0-7.77.46c-.9.24-1.6.94-1.83 1.84C2 8.8 2 12 2 12s0 3.2.4 4.7c.24.9.94 1.6 1.83 1.84C5.8 19 12 19 12 19s6.2 0 7.77-.46c.9-.24 1.6-.94 1.83-1.84C22 15.2 22 12 22 12zM10 15.2V8.8L15.5 12 10 15.2z"/></svg>`,
  google: `<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><path d="M12 2.2l1.9 5.8h6.1l-4.9 3.6 1.9 5.8-4.9-3.6-4.9 3.6 1.9-5.8-4.9-3.6h6.1z"/></svg>`,
};
const SOCIAL_LABELS = { facebook: "Facebook", instagram: "Instagram", youtube: "YouTube", google: "Google Reviews" };

function socialIconsHtml() {
  const links = Object.entries(BUSINESS.social || {}).filter(([, url]) => url);
  if (links.length === 0) return "";
  return `<div class="social-links">${links.map(([key, url]) =>
    `<a href="${url}" target="_blank" rel="noopener" aria-label="${SOCIAL_LABELS[key]}">${SOCIAL_ICONS[key]}</a>`
  ).join("")}</div>`;
}

function topbarSocialIconsHtml() {
  const links = Object.entries(BUSINESS.social || {}).filter(([, url]) => url);
  if (links.length === 0) return "";
  return `<span class="topbar-social">${links.map(([key, url]) =>
    `<a href="${url}" target="_blank" rel="noopener" aria-label="${SOCIAL_LABELS[key]}">${SOCIAL_ICONS[key]}</a>`
  ).join("")}</span>`;
}

function renderFooter() {
  const root = document.getElementById("footer-root");
  if (!root) return;
  const year = new Date().getFullYear();
  root.innerHTML = `
  <footer class="site-footer">
    <div class="container">
      <div class="footer-grid">
        <div>
          <h4>${BUSINESS.name}</h4>
          <p style="color:#C7D2D0;font-size:0.9rem;max-width:32ch;">Local appliance repair for AC, refrigerator and washing machine — same-day service across Dwarka and West Delhi.</p>
          <p style="color:#C7D2D0;font-size:0.9rem;">${BUSINESS.address}</p>
          ${socialIconsHtml()}
        </div>
        <div>
          <h4>Services</h4>
          <ul>
            <li><a href="/services/ac-repair.html">AC Repair</a></li>
            <li><a href="/services/refrigerator-repair.html">Refrigerator Repair</a></li>
            <li><a href="/services/washing-machine-repair.html">Washing Machine Repair</a></li>
            <li><a href="/services/ac-installation.html">AC Installation</a></li>
            <li><a href="/services/amc.html">Annual Maintenance (AMC)</a></li>
          </ul>
        </div>
        <div>
          <h4>Company</h4>
          <ul>
            <li><a href="/about.html">About Us</a></li>
            <li><a href="/pricing.html">Pricing</a></li>
            <li><a href="/areas-we-serve.html">Areas We Serve</a></li>
            <li><a href="/contact.html">Contact</a></li>
            <li><a href="/pay.html">Pay Online</a></li>
            <!-- Blog link removed until /blog/ content is actually built — was 404ing on every page -->
          </ul>
        </div>
        <div>
          <h4>Get in touch</h4>
          <ul>
            <li><a href="tel:${BUSINESS.phones[0].replace(/\s/g,'')}">${BUSINESS.phones[0]}</a></li>
            <li><a href="tel:${BUSINESS.phones[1].replace(/\s/g,'')}">${BUSINESS.phones[1]}</a></li>
            <li><a href="https://wa.me/${BUSINESS.whatsapp}">WhatsApp Us</a></li>
            <li>${BUSINESS.hours}</li>
          </ul>
        </div>
      </div>
      <div class="footer-bottom">
        <span>© ${year} ${BUSINESS.name}. All rights reserved.</span>
        <span><a href="/privacy-policy.html" style="color:#8FA19E;">Privacy Policy</a> · <a href="/terms.html" style="color:#8FA19E;">Terms &amp; Conditions</a></span>
      </div>
    </div>
  </footer>
  <a href="https://wa.me/${BUSINESS.whatsapp}" class="wa-float" aria-label="Chat on WhatsApp"><span class="wa-icon">💬</span> Chat with us</a>`;
}

// ---------------------------------------------------------------
// 6. BOOKING FORM — inserts into Supabase `bookings` table
// ---------------------------------------------------------------
async function handleBookingSubmit(e) {
  e.preventDefault();
  const form = e.target;
  const msgBox = document.getElementById("booking-msg");
  const submitBtn = form.querySelector('button[type="submit"]');
  msgBox.className = "form-msg";
  msgBox.textContent = "";

  const payload = {
    customer_name: form.customer_name.value.trim(),
    phone: form.phone.value.trim(),
    service_type: form.service_type.value,
    appliance_brand: form.appliance_brand.value.trim() || null,
    address: form.address.value.trim(),
    area: form.area.value,
    preferred_date: form.preferred_date.value,
    preferred_slot: form.preferred_slot.value,
    notes: form.notes.value.trim() || null,
    status: "new",
  };

  if (!payload.customer_name || !payload.phone || !payload.service_type || !payload.address) {
    msgBox.classList.add("err");
    msgBox.textContent = "Please fill in all required fields.";
    return;
  }

  submitBtn.disabled = true;
  submitBtn.textContent = "Booking...";

  try {
    const client = getClient();
    if (!client) throw new Error("Booking system not configured yet.");
    const { data, error } = await client.from("bookings").insert([payload]).select();
    if (error) throw error;

    msgBox.classList.add("ok");
    const ticketId = data && data[0] ? data[0].id : "—";
    msgBox.innerHTML = `Booking received! Your reference ID is <strong>#${ticketId}</strong>. We'll call you shortly to confirm the slot.`;
    form.reset();

    // Optional: also open WhatsApp with a prefilled summary so the customer has a copy
    const waText = encodeURIComponent(
      `New booking request:\nName: ${payload.customer_name}\nService: ${payload.service_type}\nArea: ${payload.area}\nPreferred: ${payload.preferred_date} (${payload.preferred_slot})`
    );
    const waLink = document.getElementById("booking-wa-confirm");
    if (waLink) {
      waLink.href = `https://wa.me/${BUSINESS.whatsapp}?text=${waText}`;
      waLink.style.display = "inline-flex";
    }
  } catch (err) {
    msgBox.classList.add("err");
    msgBox.textContent = "Something went wrong submitting your booking. Please call or WhatsApp us directly — " + BUSINESS.phones[0];
    console.error(err);
  } finally {
    submitBtn.disabled = false;
    submitBtn.textContent = "Book Service";
  }
}

// ---------------------------------------------------------------
// 7. CONTACT FORM — inserts into Supabase `contact_messages` table
// ---------------------------------------------------------------
async function handleContactSubmit(e) {
  e.preventDefault();
  const form = e.target;
  const msgBox = document.getElementById("contact-msg");
  msgBox.className = "form-msg";

  const payload = {
    name: form.name.value.trim(),
    phone: form.phone.value.trim(),
    message: form.message.value.trim(),
  };
  if (!payload.name || !payload.phone || !payload.message) {
    msgBox.classList.add("err");
    msgBox.textContent = "Please fill in all fields.";
    return;
  }

  try {
    const client = getClient();
    if (!client) throw new Error("not configured");
    const { error } = await client.from("contact_messages").insert([payload]);
    if (error) throw error;
    msgBox.classList.add("ok");
    msgBox.textContent = "Message sent — we'll get back to you shortly.";
    form.reset();
  } catch (err) {
    msgBox.classList.add("err");
    msgBox.textContent = "Couldn't send right now. Please call or WhatsApp us directly.";
    console.error(err);
  }
}

document.addEventListener("DOMContentLoaded", () => {
  const bookingForm = document.getElementById("booking-form");
  if (bookingForm) bookingForm.addEventListener("submit", handleBookingSubmit);
  const contactForm = document.getElementById("contact-form");
  if (contactForm) contactForm.addEventListener("submit", handleContactSubmit);
});
