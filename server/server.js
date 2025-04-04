// Import required packages
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg'); // Change from Client to Pool
require('dotenv').config();
const cors = require('cors'); // Import CORS
const { authenticateToken } = require('./jwt_token');
const multer = require('multer');
const path = require('path');
const bodyParser = require('body-parser');
const fs = require('fs');  // Add this line to import the fs module
const { body, validationResult } = require('express-validator');
const nodemailer = require('nodemailer');

// Initialize Express app
const app = express();
const port = 5003;
app.use(bodyParser.json({ limit: '50mb' }));  // For JSON requests
app.use(bodyParser.urlencoded({ limit: '50mb', extended: true }));  

app.use(cors());
// Middleware to parse JSON request body
app.use(express.json());

// PostgreSQL connection pool setup
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'flutter',
  password: 'password',
  port: 5433, 
});

pool.connect()
  .then(() => console.log('Connected to PostgreSQL'))
  .catch(err => console.error('Connection error', err.stack));

// Environment variables for JWT secret
const JWT_SECRET = process.env.JWT_SECRET || 'your_jwt_secret';

// Multer storage configuration
const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `file_${Date.now()}${ext}`); // Unique filename
  }
});

const upload = multer({ storage: storage });

// Simple GET route to test server
app.get('/', (req, res) => {
  res.send('Server is running!');
});

app.post(
  '/register',
  [
    body('name').notEmpty().withMessage('Name is required'),
    body('email')
      .matches(/^[a-zA-Z0-9._%+-]+@gmail\.com$/)
      .withMessage('Only Gmail addresses are allowed'),
    body('password')
      .isLength({ min: 5 })
      .withMessage('Password must be at least 5 characters long'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { name, email, password } = req.body;

    try {
      // Check if user already exists
      const userExists = await pool.query('SELECT * FROM Users WHERE email = $1', [email]);
      if (userExists.rows.length > 0) {
        return res.status(400).json({ message: 'Email already in use.' });
      }

      // Hash password before saving
      const hashedPassword = await bcrypt.hash(password, 10);

      // Insert user into the database
      const newUser = await pool.query(
        'INSERT INTO Users (name, email, password) VALUES ($1, $2, $3) RETURNING *',
        [name, email, hashedPassword]
      );

      res.status(201).json({ message: 'User registered successfully', user: newUser.rows[0] });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error' });
    }
  }
);

// Login route
app.post('/login', async (req, res) => {
  const { email, password } = req.body;

  try {
    // Query the database to find the user by email
    const query = 'SELECT * FROM users WHERE email = $1';
    const result = await pool.query(query, [email]);

    if (result.rows.length === 0) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }
    const user = result.rows[0];
    // Compare the password with the stored hashed password
    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }
    // Generate JWT token
    const token = jwt.sign(
      { userId: user.id, email: user.email },
      JWT_SECRET,
      //{ expiresIn: '1h' } // Optional expiration time
    );

    // Send response with token and user_id
    res.status(200).json({
      message: 'Login successful', 
      token,        // JWT Token
      user_id: user.id, // Return user ID in the response
    });
  } catch (err) {
    console.error('Error during login', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create a Nodemailer transporter using Gmail
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
  tls: {
    rejectUnauthorized: false, 
  },
});   

// Password reset route
app.post('/send-reset-link', async (req, res) => {
  const { email } = req.body;

  // Check if email is valid
  if (!email || !email.includes('@gmail.com')) {
    return res.status(400).json({ message: 'Invalid email address' });
  }

  try {
    // Check if the email exists in the database
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'We cannot find your email, re-check your email!!!' });
    }

    // Generate the reset URL
    const resetUrl = `http://localhost:63526/reset-password?email=${email}`;

    // Create the mailOptions object to send the reset link
    const mailOptions = {
      from: process.env.EMAIL_USER, // The email from which the reset link will be sent
      to: email, // Send to the email that requested the reset
      subject: 'Password Reset Request',
      text: `Hello, you can reset your password here: ${resetUrl}`, 
    };

    // Send email to the requested user
    await transporter.sendMail(mailOptions);

    return res.status(200).json({ message: 'Password reset link sent!' });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ message: 'Error sending email', error: error.message });
  }
});

// Route to reset password (this is just a placeholder)
app.post('/reset-password', async (req, res) => {
  const { email, newPassword } = req.body;

  if (!newPassword || newPassword.length < 5) {
    return res.status(400).json({ success: false, message: 'Password must be at least 5 characters long.' });
  }

  try {
    // Hash the new password before saving
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    // Update password in the database
    const result = await pool.query('UPDATE users SET password = $1 WHERE email = $2', [hashedPassword, email]);

    // Check if any rows were updated
    if (result.rowCount === 0) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    // Generate new JWT token
    const userResult = await pool.query('SELECT id, email FROM users WHERE email = $1', [email]);
    const user = userResult.rows[0];

    const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, { expiresIn: '1h' });

    return res.status(200).json({
      success: true,
      message: 'Password has been reset successfully.',
      token: token
    });

  } catch (error) {
    console.error(error);
    return res.status(500).json({ success: false, message: 'Error resetting password' });
  }
});

// Route to test JWT authentication
app.get('/profile', (req, res) => {
  const token = req.headers['authorization'];

  if (!token) {
    return res.status(403).json({ message: 'No token provided' });
  }
  // Verify JWT token
  jwt.verify(token, JWT_SECRET, (err, decoded) => {
    if (err) {
      return res.status(401).json({ message: 'Invalid or expired token' });
    }

    res.status(200).json({
      message: 'Profile data',
      userId: decoded.userId,
      email: decoded.email,
    });
  }); 
});

app.get("/chat-list", authenticateToken, async (req, res) => {
  const userId = req.userId; // Logged-in user's ID
  console.log("Fetching chat list for userId:", req.userId);
  
  try {
    // First, check if the logged-in user has ever sent a message to themselves
    const selfMessageQuery = `
      SELECT EXISTS (
        SELECT 1 
        FROM messages 
        WHERE (sender_id = $1 AND receiver_id = $1)
      ) AS sent_to_self;
    `;
    const selfMessageResult = await pool.query(selfMessageQuery, [userId]);
    const sentToSelf = selfMessageResult.rows[0].sent_to_self;

    // Query to get the latest messages for each conversation involving the logged-in user
    const query = `
      WITH latest_messages AS (
        SELECT DISTINCT ON (LEAST(sender_id, receiver_id), GREATEST(sender_id, receiver_id)) 
               sender_id, receiver_id, message, created_at
        FROM messages
        WHERE sender_id = $1 OR receiver_id = $1
        ORDER BY LEAST(sender_id, receiver_id), GREATEST(sender_id, receiver_id), created_at DESC
      )
      -- Get all conversations where the logged-in user is involved
      SELECT 
        u.id, 
        u.name, 
        u.image, 
        CASE 
          WHEN u.id = $1 AND NOT $2 THEN 'No messages yet'  -- If logged-in user has never sent to themselves
          ELSE COALESCE(lm.message, 'No messages yet') 
        END AS last_message, 
        COALESCE(lm.created_at, NOW()) AS last_message_time
      FROM latest_messages lm
      JOIN users u ON u.id = (
        CASE 
          WHEN lm.sender_id = $1 THEN lm.receiver_id  -- If logged-in user is sender, get receiver
          ELSE lm.sender_id  -- Otherwise, get sender
        END
      )
      WHERE u.id != $1  -- Exclude the logged-in user from the list
      UNION
      -- Include the logged-in user in their own chat with the appropriate message
      SELECT 
        u.id, 
        u.name, 
        u.image, 
        CASE 
          WHEN $2 THEN lm.message
          ELSE 'No messages yet'
        END AS last_message, 
        COALESCE(lm.created_at, NOW()) AS last_message_time
      FROM users u
      LEFT JOIN latest_messages lm ON lm.sender_id = $1 AND lm.receiver_id = $1
      WHERE u.id = $1  -- Ensure the logged-in user is included
      ORDER BY last_message_time DESC;
    `;

    // Execute the query
    const result = await pool.query(query, [userId, sentToSelf]);
    // Check if there are any results
    if (result.rows.length === 0) {
      return res.status(404).json({ message: "No chat history found" });
    }
    // Send the response with the latest chat list
    res.json(result.rows);
  } catch (err) {
    console.error("Error fetching chat list:", err);
    res.status(500).json({ message: "Internal Server Error" });
  }
});

// Endpoint to send a message (with optional file upload)
app.post('/send-message', authenticateToken, async (req, res) => {
  const { receiver_id, message, file, fileName, fileType } = req.body; 
  const sender_id = req.userId;

  if (!receiver_id || (!message && !file)) {
    return res.status(400).json({ message: 'Receiver ID and Message or File are required' });
  }

  try {
    const receiverQuery = 'SELECT * FROM users WHERE id = $1';
    const receiverResult = await pool.query(receiverQuery, [receiver_id]);

    if (receiverResult.rows.length === 0) {
      return res.status(400).json({ message: `Receiver with ID ${receiver_id} does not exist` });
    }

    let storedMessage = message; // Store the plain text message directly

    if (file) {
      // Store the file as binary in the database (only for images)
      const fileData = Buffer.from(file, 'base64');
      const storedFileName = fileName || 'default_file_name';
      const fileTypeLower = fileType.toLowerCase();

      // Insert image file into the database
      const fileInsertQuery = 'INSERT INTO files (file_data, file_name, file_type) VALUES ($1, $2, $3) RETURNING id';
      const fileInsertResult = await pool.query(fileInsertQuery, [fileData, storedFileName, fileTypeLower]);

      const fileId = fileInsertResult.rows[0].id;

      // Adjust message to reference the file if it's an image
      storedMessage = JSON.stringify({
        type: fileTypeLower,
        file_id: fileId,
        name: storedFileName,
      });
    }

    // Insert the message into the database
    const insertQuery = 'INSERT INTO messages (sender_id, receiver_id, message) VALUES ($1, $2, $3)';
    await pool.query(insertQuery, [sender_id, receiver_id, storedMessage]);

    return res.status(200).json({ message: 'Message sent successfully' });
  } catch (e) {
    console.error('Error while sending message:', e);
    return res.status(500).json({ message: 'Internal server error' });
  }
});


// Fetching messages between two users
// Fetching messages between two users
app.get('/messages', authenticateToken, async (req, res) => {
  const userId = req.userId;
  const { sender_id, receiver_id } = req.query;

  if (!sender_id || !receiver_id) {
    return res.status(400).json({ message: "sender_id and receiver_id are required" });
  }

  const senderIdInt = parseInt(sender_id, 10);
  const receiverIdInt = parseInt(receiver_id, 10);

  if (isNaN(senderIdInt) || isNaN(receiverIdInt)) {
    return res.status(400).json({ message: "sender_id and receiver_id must be valid integers" });
  }

  if (userId !== senderIdInt && userId !== receiverIdInt) {
    return res.status(403).json({ message: "Forbidden" });
  }

  try {
    const query = `
      SELECT * FROM messages 
      WHERE (sender_id = $1 AND receiver_id = $2) 
         OR (sender_id = $2 AND receiver_id = $1) 
      ORDER BY created_at ASC;
    `;
    const result = await pool.query(query, [senderIdInt, receiverIdInt]);

    if (result.rows.length === 0) {
      return res.status(404).json({ message: "No messages found" });
    }

    const messages = result.rows.map((msg) => {
      let fileData = null;
      let fileUrl = null;
      let messageContent = '';

      try {
        if (msg.message) {
          // If the message is text (not JSON), it is stored directly as text
          if (typeof msg.message === 'string') {
            messageContent = msg.message;
          } else {
            // If it's a file or JSON string, handle it accordingly
            let message;
            try {
              message = JSON.parse(msg.message); // Parsing the JSON if necessary
            } catch (error) {
              console.error('Error parsing message:', error);
              message = {}; // Fallback to empty object if parsing fails
            }

            // Handle different message types
            if (message.type === 'pdf') {
              fileUrl = `/download/${message.name}`; // Assuming you have a file download URL route
            } else if (message.type === 'image') {
              fileData = message.data; // Base64 image data
            }

            messageContent = message.content || ''; // Default to empty string if no content
          }
        }
      } catch (error) {
        console.error('Error processing message:', error);
      }

      return {
        ...msg,
        message: messageContent,
        fileData,
        fileUrl,
      };
    });

    return res.json(messages);
  } catch (err) {
    console.error('Error fetching messages:', err);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});


// Start server
app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});
