import swaggerJSDoc from 'swagger-jsdoc';

const jsonContent = (schema) => ({
  'application/json': {
    schema,
  },
});

const authSchema = {
  type: 'object',
  properties: {
    email: { type: 'string' },
    password: { type: 'string' },
    token: { type: 'string' },
  },
};

const reservationSchema = {
  type: 'object',
  properties: {
    tripid: { type: 'string', format: 'uuid' },
    seatlocation: { type: 'string' },
    dropoffpoint: { type: 'string' },
    paymentmethod: { type: 'string', enum: ['wallet', 'cash', 'card', 'palpay', 'jawwal_pay'] },
  },
  required: ['tripid'],
};

const options = {
  definition: {
    openapi: '3.0.3',
    info: {
      title: 'Service Taxi Reservation API',
      version: '1.0.0',
      description: 'API documentation for the Service Taxi Reservation and Management System',
    },
    servers: [
      {
        url: `http://localhost:${process.env.PORT || 3000}/api`,
        description: 'Local server',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
    },
    security: [
      {
        bearerAuth: [],
      },
    ],
    tags: [
      { name: 'Auth' },
      { name: 'Lines' },
      { name: 'Trips' },
      { name: 'Reservations' },
      { name: 'Vehicles' },
      { name: 'Payments' },
      { name: 'Wallets' },
      { name: 'Admin' },
    ],
    paths: {
      '/auth/register': {
        post: {
          tags: ['Auth'],
          summary: 'Register a new user',
          requestBody: {
            required: true,
            content: jsonContent({
              type: 'object',
              required: ['fullname', 'email', 'password', 'role'],
              properties: {
                fullname: { type: 'string' },
                email: { type: 'string' },
                password: { type: 'string' },
                phone: { type: 'string' },
                role: { type: 'string', enum: ['admin', 'driver', 'passenger'] },
              },
            }),
          },
          responses: {
            201: { description: 'User registered' },
            400: { description: 'Email exists or validation error' },
          },
        },
      },
      '/auth/login': {
        post: {
          tags: ['Auth'],
          summary: 'Login',
          requestBody: {
            required: true,
            content: jsonContent({
              type: 'object',
              required: ['email', 'password'],
              properties: {
                email: { type: 'string' },
                password: { type: 'string' },
              },
            }),
          },
          responses: {
            200: { description: 'Login success', content: jsonContent(authSchema) },
            401: { description: 'Invalid credentials' },
          },
        },
      },
      '/auth/profile': {
        get: {
          tags: ['Auth'],
          summary: 'Get current user profile',
          responses: { 200: { description: 'Profile data' } },
        },
        put: {
          tags: ['Auth'],
          summary: 'Update profile',
          requestBody: { content: jsonContent({ type: 'object' }) },
          responses: { 200: { description: 'Profile updated' } },
        },
      },
      '/auth/change-password': {
        put: {
          tags: ['Auth'],
          summary: 'Change password',
          requestBody: {
            required: true,
            content: jsonContent({
              type: 'object',
              required: ['currentPassword', 'newPassword'],
              properties: {
                currentPassword: { type: 'string' },
                newPassword: { type: 'string' },
              },
            }),
          },
          responses: { 200: { description: 'Password changed' } },
        },
      },
      '/auth/password/reset/request': {
        post: {
          tags: ['Auth'],
          summary: 'Request password reset',
          requestBody: {
            required: true,
            content: jsonContent({ type: 'object', required: ['email'], properties: { email: { type: 'string' } } }),
          },
          responses: { 200: { description: 'Reset email sent' } },
        },
      },
      '/auth/password/reset/verify': {
        post: {
          tags: ['Auth'],
          summary: 'Verify reset code',
          requestBody: {
            required: true,
            content: jsonContent({
              type: 'object',
              required: ['email', 'code'],
              properties: {
                email: { type: 'string' },
                code: { type: 'string' },
              },
            }),
          },
          responses: { 200: { description: 'Code verified' } },
        },
      },
      '/auth/password/reset/confirm': {
        post: {
          tags: ['Auth'],
          summary: 'Confirm password reset',
          requestBody: {
            required: true,
            content: jsonContent({
              type: 'object',
              required: ['email', 'code', 'newPassword'],
              properties: {
                email: { type: 'string' },
                code: { type: 'string' },
                newPassword: { type: 'string' },
              },
            }),
          },
          responses: { 200: { description: 'Password reset success' } },
        },
      },
      '/auth/check-user': {
        post: {
          tags: ['Auth'],
          summary: 'Check user information',
          requestBody: {
            required: true,
            content: jsonContent({
              type: 'object',
              required: ['email'],
              properties: {
                email: { type: 'string' },
              },
            }),
          },
          responses: { 200: { description: 'User information' } },
        },
      },
      '/auth/admin/reset-password': {
        post: {
          tags: ['Auth'],
          summary: 'Admin password reset (direct)',
          requestBody: {
            required: true,
            content: jsonContent({
              type: 'object',
              required: ['email', 'newPassword'],
              properties: {
                email: { type: 'string' },
                newPassword: { type: 'string' },
              },
            }),
          },
          responses: { 
            200: { description: 'Password reset successfully' },
            403: { description: 'Only for admin users' },
            404: { description: 'User not found' },
          },
        },
      },
      '/lines': {
        get: { tags: ['Lines'], summary: 'List lines', responses: { 200: { description: 'List of lines' } } },
        post: {
          tags: ['Lines'],
          summary: 'Create line (Admin)',
          responses: { 201: { description: 'Line created' }, 403: { description: 'Requires admin' } },
        },
      },
      '/lines/active': {
        get: { tags: ['Lines'], summary: 'List active lines', responses: { 200: { description: 'Active lines' } } },
      },
      '/lines/{lineid}': {
        get: { tags: ['Lines'], summary: 'Get line', parameters: [{ name: 'lineid', in: 'path', required: true }], responses: { 200: { description: 'Line data' }, 404: { description: 'Not found' } } },
        put: { tags: ['Lines'], summary: 'Update line (Admin)', parameters: [{ name: 'lineid', in: 'path', required: true }], responses: { 200: { description: 'Updated' } } },
        delete: { tags: ['Lines'], summary: 'Deactivate line (Admin)', parameters: [{ name: 'lineid', in: 'path', required: true }], responses: { 200: { description: 'Deleted' } } },
      },
      '/trips': {
        get: { tags: ['Trips'], summary: 'List trips', responses: { 200: { description: 'Trips list' } } },
        post: { tags: ['Trips'], summary: 'Create trip (Admin)', responses: { 201: { description: 'Trip created' } } },
      },
      '/trips/upcoming': {
        get: { tags: ['Trips'], summary: 'Upcoming trips', responses: { 200: { description: 'Upcoming trips' } } },
      },
      '/trips/{tripid}': {
        get: { tags: ['Trips'], summary: 'Trip details', parameters: [{ name: 'tripid', in: 'path', required: true }], responses: { 200: { description: 'Trip data' } } },
        put: { tags: ['Trips'], summary: 'Update trip (Admin)', parameters: [{ name: 'tripid', in: 'path', required: true }], responses: { 200: { description: 'Updated' } } },
      },
      '/trips/{tripid}/seatmap': {
        get: { tags: ['Trips'], summary: 'Get trip seat map', parameters: [{ name: 'tripid', in: 'path', required: true }], responses: { 200: { description: 'Seat map' } } },
      },
      '/trips/{tripid}/start': {
        put: { tags: ['Trips'], summary: 'Start trip (Driver)', parameters: [{ name: 'tripid', in: 'path', required: true }], responses: { 200: { description: 'Started' } } },
      },
      '/trips/{tripid}/end': {
        put: { tags: ['Trips'], summary: 'End trip (Driver)', parameters: [{ name: 'tripid', in: 'path', required: true }], responses: { 200: { description: 'Ended' } } },
      },
      '/reservations': {
        get: { tags: ['Reservations'], summary: 'All reservations (Admin)', responses: { 200: { description: 'Reservations' } } },
        post: {
          tags: ['Reservations'],
          summary: 'Create reservation (Passenger)',
          requestBody: { required: true, content: jsonContent(reservationSchema) },
          responses: { 201: { description: 'Reservation created' } },
        },
      },
      '/reservations/my-reservations': {
        get: { tags: ['Reservations'], summary: 'My reservations (Passenger)', responses: { 200: { description: 'List' } } },
      },
      '/reservations/{bookingid}': {
        get: { tags: ['Reservations'], summary: 'Reservation by ID (Admin)', parameters: [{ name: 'bookingid', in: 'path', required: true }], responses: { 200: { description: 'Reservation data' } } },
        put: { tags: ['Reservations'], summary: 'Update reservation (Admin)', parameters: [{ name: 'bookingid', in: 'path', required: true }], responses: { 200: { description: 'Updated' } } },
      },
      '/reservations/{bookingid}/cancel': {
        put: { tags: ['Reservations'], summary: 'Cancel reservation (Passenger)', parameters: [{ name: 'bookingid', in: 'path', required: true }], responses: { 200: { description: 'Cancelled' } } },
      },
      '/reservations/check-in': {
        post: { tags: ['Reservations'], summary: 'Driver check-in passenger', responses: { 200: { description: 'Checked in' } } },
      },
      '/vehicles': {
        get: { tags: ['Vehicles'], summary: 'List vehicles', responses: { 200: { description: 'Vehicles' } } },
        post: { tags: ['Vehicles'], summary: 'Create vehicle (Admin)', responses: { 201: { description: 'Vehicle created' } } },
      },
      '/vehicles/{vehicleid}': {
        get: { tags: ['Vehicles'], summary: 'Get vehicle', parameters: [{ name: 'vehicleid', in: 'path', required: true }], responses: { 200: { description: 'Vehicle data' } } },
        put: { tags: ['Vehicles'], summary: 'Update vehicle (Admin)', parameters: [{ name: 'vehicleid', in: 'path', required: true }], responses: { 200: { description: 'Updated' } } },
      },
      '/vehicles/driver/my-vehicles': {
        get: { tags: ['Vehicles'], summary: 'Driver vehicles', responses: { 200: { description: 'List' } } },
      },
      '/vehicles/{vehicleid}/assign-line': {
        put: { tags: ['Vehicles'], summary: 'Assign line (Admin)', parameters: [{ name: 'vehicleid', in: 'path', required: true }], responses: { 200: { description: 'Assigned' } } },
      },
      '/payments/my-payments': {
        get: { tags: ['Payments'], summary: 'My payments', responses: { 200: { description: 'Payments' } } },
      },
      '/payments': {
        post: { tags: ['Payments'], summary: 'Create payment', responses: { 201: { description: 'Payment created' } } },
        get: { tags: ['Payments'], summary: 'All payments (Admin)', responses: { 200: { description: 'Payments' } } },
      },
      '/payments/{paymentid}': {
        get: { tags: ['Payments'], summary: 'Payment by ID (Admin)', parameters: [{ name: 'paymentid', in: 'path', required: true }], responses: { 200: { description: 'Payment data' } } },
      },
      '/payments/{paymentid}/status': {
        put: { tags: ['Payments'], summary: 'Update payment status (Admin)', parameters: [{ name: 'paymentid', in: 'path', required: true }], responses: { 200: { description: 'Updated' } } },
      },
      '/wallets': {
        get: { tags: ['Wallets'], summary: 'My wallets', responses: { 200: { description: 'Wallet list' } } },
        post: { tags: ['Wallets'], summary: 'Create wallet', responses: { 201: { description: 'Wallet created' } } },
      },
      '/wallets/{walletid}': {
        get: { tags: ['Wallets'], summary: 'Get wallet', parameters: [{ name: 'walletid', in: 'path', required: true }], responses: { 200: { description: 'Wallet data' } } },
      },
      '/wallets/{walletid}/add-balance': {
        post: { tags: ['Wallets'], summary: 'Add balance', parameters: [{ name: 'walletid', in: 'path', required: true }], responses: { 200: { description: 'Balance added' } } },
      },
      '/admin/dashboard/stats': {
        get: { tags: ['Admin'], summary: 'Dashboard stats', responses: { 200: { description: 'Stats' } } },
      },
      '/admin/dashboard/revenue': {
        get: { tags: ['Admin'], summary: 'Revenue analytics', responses: { 200: { description: 'Revenue data' } } },
      },
      '/admin/users': {
        get: { tags: ['Admin'], summary: 'All users', responses: { 200: { description: 'Users' } } },
      },
      '/admin/users/{userid}': {
        get: { tags: ['Admin'], summary: 'User by ID', parameters: [{ name: 'userid', in: 'path', required: true }], responses: { 200: { description: 'User data' } } },
        put: { tags: ['Admin'], summary: 'Update user', parameters: [{ name: 'userid', in: 'path', required: true }], responses: { 200: { description: 'Updated' } } },
        delete: { tags: ['Admin'], summary: 'Delete user', parameters: [{ name: 'userid', in: 'path', required: true }], responses: { 200: { description: 'Deleted' } } },
      },
      '/admin/admins/{adminid}/permissions': {
        put: { tags: ['Admin'], summary: 'Update admin permissions', parameters: [{ name: 'adminid', in: 'path', required: true }], responses: { 200: { description: 'Permissions updated' } } },
      },
    },
  },
  apis: [],
};

const swaggerSpec = swaggerJSDoc(options);

export default swaggerSpec;

