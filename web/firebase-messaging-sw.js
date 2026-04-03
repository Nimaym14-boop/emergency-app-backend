// web/firebase-messaging-sw.js

// 1. Import the scripts needed for background messaging
importScripts("https://www.gstatic.com/firebasejs/10.0.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.0.0/firebase-messaging-compat.js");

// 2. Initialize Firebase in the service worker
// Use the exact config Person 3 provided
firebase.initializeApp({
  apiKey: "AIzaSyBmy69cqwvJi9q5I98AVln_qGglL9lCRNM",
  authDomain: "emergency-app-16163.firebaseapp.com",
  projectId: "emergency-app-16163",
  storageBucket: "emergency-app-16163.firebasestorage.app",
  messagingSenderId: "594138423990",
  appId: "1:594138423990:web:9f4cfb0d5187da80fffc17",
});

// 3. Retrieve an instance of Firebase Messaging
const messaging = firebase.messaging();

// 4. Handle background messages (Optional: customizes how notifications look)
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png' // Ensure this path exists in your web folder
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});