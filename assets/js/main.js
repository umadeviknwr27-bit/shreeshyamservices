/* Shree Shyam Services — shared JS
   Pattern: renderNav()/renderFooter() injected into #nav-root / #footer-root on every page,
   same convention used on ZoomFly (main.js). Keeps every page thin.
*/

// ---------------------------------------------------------------
// 1. SUPABASE CONFIG — replace with your project's values.
//    Find these in Supabase Dashboard > Project Settings > API
// ---------------------------------------------------------------
const SUPABASE_URL = "YOUR_SUPABASE_PROJECT_URL"; // e.g. https://xxxxx.supabase.co
const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY"; // the eyJ... anon/public key

// Loaded via CDN script tag in each page (see <head>), exposes window.supabase
let sb = null;
function getClient() {
  if (!sb && window.supabase) {
    sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  }
  return sb;
}

// ---------------------------------------------------------------
// 2. BUSINESS INFO — single source of truth, used across nav/footer/contact
// ---------------------------------------------------------------
const BUSINESS = {
  name: "Shree Shyam Services",
  phones: ["+91 9599459187", "+91 7011509629"],
  whatsapp: "919599459187", // primary, no + or spaces, for wa.me links
  address: "B1/46 Bharat Vihar, Kakrola, near Deepika International School, Sector 14, Dwarka, New Delhi",
  areas: ["Dwarka", "Sector 6", "Sector 7", "Sector 10", "Sector 12", "Sector 14", "Sector 22", "Uttam Nagar", "Najafgarh", "West Delhi"],
  hours: "10:00 AM – 10:00 PM, All 7 days",
};

// ---------------------------------------------------------------
// 3. NAV
// ---------------------------------------------------------------
function renderNav(activePage = "") {
  const root = document.getElementById("nav-root");
  if (!root) return;
  const wa = `https://wa.me/${BUSINESS.whatsapp}?text=${encodeURIComponent("Hi, I need help with an appliance repair.")}`;
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
        </div>
      </div>
    </div>
    <nav class="container navwrap">
      <a href="/index.html" class="brand">
        <span class="brand-mark">SS</span>
        <span class="brand-text">Shree Shyam Services<span>Appliance Repair &amp; AMC</span></span>
      </a>
      <ul class="nav-links">
        <li><a href="/index.html" ${activePage==='home'?'class="active"':''}>Home</a></li>
        <li><a href="/about.html" ${activePage==='about'?'class="active"':''}>About</a></li>
        <li><a href="/services/index.html" ${activePage==='services'?'class="active"':''}>Services</a></li>
        <li><a href="/pricing.html" ${activePage==='pricing'?'class="active"':''}>Pricing</a></li>
        <li><a href="/areas-we-serve.html" ${activePage==='areas'?'class="active"':''}>Areas We Serve</a></li>
        <li><a href="/contact.html" ${activePage==='contact'?'class="active"':''}>Contact</a></li>
      </ul>
      <div class="nav-cta">
        <a href="${wa}" class="btn btn-wa" style="padding:9px 16px;font-size:0.88rem;">WhatsApp</a>
        <a href="/book-service.html" class="btn btn-primary" style="padding:9px 18px;font-size:0.88rem;">Book Service</a>
      </div>
    </nav>
  </header>`;
}

// ---------------------------------------------------------------
// 4. FOOTER
// ---------------------------------------------------------------
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
            <li><a href="/blog/index.html">Blog</a></li>
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
  <a href="https://wa.me/${BUSINESS.whatsapp}" class="wa-float" aria-label="Chat on WhatsApp">💬</a>`;
}

// ---------------------------------------------------------------
// 5. BOOKING FORM — inserts into Supabase `bookings` table
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
// 6. CONTACT FORM — inserts into Supabase `contact_messages` table
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
