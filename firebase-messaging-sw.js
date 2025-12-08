importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
   apiKey: 'AIzaSyB_r30ONnEVlS3WUEFJvQT557GCGFWcOaQ',
       appId: '1:61080839736:web:e22500d78f06d5eea468cd',
       messagingSenderId: '61080839736',
       projectId: 'tdm-25-2',
       authDomain: 'tdm-25-2.firebaseapp.com',
       storageBucket: 'tdm-25-2.firebasestorage.app',
});

const messaging = firebase.messaging();

// Optional:
messaging.onBackgroundMessage((message) => {
  console.log("onBackgroundMessage", message);
});