// Replace this base with the API Gateway URL output by Terraform (see outputs)
// If you are hosting frontend on the S3 website, you can embed the real API base via a small script or edit here.
let API_BASE = "https://6rdvr56w30.execute-api.us-east-1.amazonaws.com/prod";
//let API_BASE = "https://6rdvr56w30.execute-api.us-east-1.amazonaws.com/prod ";

async function init() {
  // Try to configure API_BASE from a JSON file or from the same host
  // For examples assume you put the API URL manually here or update this variable
  if (!API_BASE) {
    // If the index page was uploaded by Terraform, you can manually replace API_BASE below with the output api url
    // Example:
    // API_BASE = "https://{restapi-id}.execute-api.us-east-1.amazonaws.com/prod";
    console.warn("API_BASE is not configured. After Terraform apply, edit script.js to set API_BASE to the API Gateway URL from outputs.");
  }

  document.getElementById("createBtn").onclick = createBooking;
  document.getElementById("updateBtn").onclick = updateBooking;
  document.getElementById("cancelBtn").onclick = cancelBooking;
  document.getElementById("refreshBtn").onclick = listBookings;

  await listBookings();
}

async function createBooking() {
  const patient_name = document.getElementById("patient_name").value;
  const date = document.getElementById("date").value;
  const time = document.getElementById("time").value;

  const resp = await fetch(`${API_BASE}/book`, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({ patient_name, date, time })
  });

  const data = await resp.json();
  alert(JSON.stringify(data));
  await listBookings();
}

async function updateBooking() {
  const booking_id = document.getElementById("update_booking_id").value;
  const patient_name = document.getElementById("update_patient_name").value;
  const date = document.getElementById("update_date").value;
  const time = document.getElementById("update_time").value;

  const payload = { booking_id };
  if (patient_name) payload.patient_name = patient_name;
  if (date) payload.date = date;
  if (time) payload.time = time;

  const resp = await fetch(`${API_BASE}/update`, {
    method: "PUT",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(payload)
  });

  const data = await resp.json();
  alert(JSON.stringify(data));
  await listBookings();
}

async function cancelBooking() {
  const booking_id = document.getElementById("cancel_booking_id").value;
  const resp = await fetch(`${API_BASE}/cancel?booking_id=${encodeURIComponent(booking_id)}`, {
    method: "DELETE"
  });
  const data = await resp.json();
  alert(JSON.stringify(data));
  await listBookings();
}

async function listBookings() {
  const pre = document.getElementById("bookingsList");
  if (!API_BASE) {
    pre.innerText = "API not configured. Set API_BASE in script.js to the API URL from Terraform outputs.";
    return;
  }

  const resp = await fetch(`${API_BASE}/bookings`);
  const data = await resp.json();
  pre.innerText = JSON.stringify(data, null, 2);
}

window.onload = init;

