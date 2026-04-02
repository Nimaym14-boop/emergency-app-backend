import { initializeApp } from "https://www.gstatic.com/firebasejs/10.0.0/firebase-app.js";
import { getFirestore, collection, addDoc, doc, updateDoc, serverTimestamp } from "https://www.gstatic.com/firebasejs/10.0.0/firebase-firestore.js";
import { getMessaging, getToken } from "https://www.gstatic.com/firebasejs/10.0.0/firebase-messaging.js";

const firebaseConfig = {
  apiKey: "AIzaSyBmy69cqwvJi9q5I98AVln_qGglL9lCRNM",
  authDomain: "emergency-app-16163.firebaseapp.com",
  projectId: "emergency-app-16163",
  storageBucket: "emergency-app-16163.firebasestorage.app",
  messagingSenderId: "594138423990",
  appId: "Hidden for security",
  measurementId: "G-RXF3EE7LCH"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const messaging = getMessaging(app);

//  This is for Person 1 (The Bot) to send GPS data
export async function reportIncident(name, room, category, lat, lng) {
  try {
    const res = await addDoc(collection(db, "Incidents"), {
      guestName: name,
      location: room,
      type: category,
      status: "Pending",
      lat: lat,
      lng: lng,
      timeSent: serverTimestamp()
    });
    console.log("Entry created: " + res.id);
  } catch (err) {
    console.log("Database error: " + err);
  }
}

// This is for Person 2 (The Dashboard) to click "Resolve"
export async function updateIncidentStatus(incidentId, newStatus) {
  try {
    const incidentRef = doc(db, "Incidents", incidentId);
    await updateDoc(incidentRef, {
      status: newStatus,
      resolvedAt: serverTimestamp()
    });
    console.log("Status updated to: " + newStatus);
  } catch (err) {
    console.log("Update failed: " + err);
  }
}

export function initMessaging() {
  const vapidKey = "BFOdRK3zv6mVqzVq0W3pZM-ojVxcJ7cBxVDhsmu1CQtbwPmw2WB9SaZNjSts6CiKGbg48LpBBvlDTVve3b6yv9o";
  getToken(messaging, { vapidKey: vapidKey }).then((token) => {
    if (token) console.log("Push token: " + token);
  });
}
