<?php
// contact-handler.php - Place in /var/www/domain/host/contact/index.php

// Set strict error reporting
declare(strict_types=1);
error_reporting(E_ALL);
ini_set('display_errors', '0');

class ContactFormHandler {
    private string $logFile;
    private string $rateFile;
    private array $config;
    
    public function __construct() {
        $this->logFile = dirname(__DIR__) . '/logs/contact_form.log';
        $this->rateFile = dirname(__DIR__) . '/tmp/rate_limit.json';
        
        // Load site-specific configuration
        $this->config = $this->loadConfig();
    }
    
    private function loadConfig(): array {
        $configFile = dirname(__DIR__) . '/config/contact.json';
        if (!file_exists($configFile)) {
            throw new Exception('Configuration file not found');
        }
        return json_decode(file_get_contents($configFile), true);
    }
    
    private function validateRequest(): void {
        // Check if it's a POST request
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            $this->respondWithError('Invalid request method');
        }

        // Verify CSRF token
        if (!isset($_POST['csrf_token']) || 
            $_POST['csrf_token'] !== $_SESSION['csrf_token']) {
            $this->respondWithError('Invalid security token');
        }

        // Check honeypot field
        if (!empty($_POST['website'])) { // Hidden field for bots
            $this->respondWithError('Spam detected');
        }

        // Validate required fields
        $requiredFields = ['name', 'email', 'message'];
        foreach ($requiredFields as $field) {
            if (empty($_POST[$field])) {
                $this->respondWithError("Missing required field: {$field}");
            }
        }

        // Validate email format
        if (!filter_var($_POST['email'], FILTER_VALIDATE_EMAIL)) {
            $this->respondWithError('Invalid email format');
        }
    }
    
    private function checkRateLimit(): void {
        $ip = $_SERVER['REMOTE_ADDR'];
        $now = time();
        $rateLimits = [];
        
        if (file_exists($this->rateFile)) {
            $rateLimits = json_decode(file_get_contents($this->rateFile), true);
        }
        
        // Clean up old entries
        $rateLimits = array_filter($rateLimits, function($timestamp) use ($now) {
            return $timestamp > ($now - 3600); // Keep last hour
        });
        
        // Check rate limit (5 requests per hour per IP)
        if (isset($rateLimits[$ip]) && count($rateLimits[$ip]) >= 5) {
            $this->respondWithError('Rate limit exceeded');
        }
        
        // Add new timestamp
        $rateLimits[$ip][] = $now;
        
        // Save updated rate limits
        file_put_contents($this->rateFile, json_encode($rateLimits));
    }
    
    private function sanitizeInput(string $input): string {
        return htmlspecialchars(trim($input), ENT_QUOTES, 'UTF-8');
    }
    
    private function logMessage(array $data): void {
        $logEntry = date('Y-m-d H:i:s') . ' - ' . json_encode($data) . PHP_EOL;
        file_put_contents($this->logFile, $logEntry, FILE_APPEND);
    }
    
    private function sendEmail(array $data): void {
        $to = $this->config['recipient_email'];
        $subject = "[Contact Form] New message from {$data['name']}";
        
        // Build email body with sanitized data
        $message = "Name: {$data['name']}\n";
        $message .= "Email: {$data['email']}\n";
        $message .= "Message:\n{$data['message']}\n";
        
        // Add IP and timestamp for tracking
        $message .= "\n---\n";
        $message .= "Sent from: {$_SERVER['REMOTE_ADDR']}\n";
        $message .= "Date: " . date('Y-m-d H:i:s') . "\n";
        
        // Set headers
        $headers = [
            'From' => $this->config['from_email'],
            'Reply-To' => $data['email'],
            'X-Mailer' => 'PHP/' . phpversion(),
            'Content-Type' => 'text/plain; charset=UTF-8'
        ];
        
        // Send email
        if (!mail($to, $subject, $message, $headers)) {
            throw new Exception('Failed to send email');
        }
    }
    
    private function respondWithError(string $message): void {
        http_response_code(400);
        echo json_encode(['error' => $message]);
        exit;
    }
    
    private function respondWithSuccess(): void {
        http_response_code(200);
        echo json_encode(['success' => true]);
        exit;
    }
    
    public function handle(): void {
        try {
            session_start();
            
            // Generate CSRF token if not exists
            if (empty($_SESSION['csrf_token'])) {
                $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
            }
            
            if ($_SERVER['REQUEST_METHOD'] === 'GET') {
                // Return CSRF token for form
                echo json_encode(['csrf_token' => $_SESSION['csrf_token']]);
                exit;
            }
            
            // Process POST request
            $this->validateRequest();
            $this->checkRateLimit();
            
            // Sanitize input data
            $data = [
                'name' => $this->sanitizeInput($_POST['name']),
                'email' => $this->sanitizeInput($_POST['email']),
                'message' => $this->sanitizeInput($_POST['message'])
            ];
            
            // Send email
            $this->sendEmail($data);
            
            // Log successful submission
            $this->logMessage($data);
            
            $this->respondWithSuccess();
            
        } catch (Exception $e) {
            error_log("Contact form error: " . $e->getMessage());
            $this->respondWithError('An error occurred processing your request');
        }
    }
}

// Initialize and handle request
$handler = new ContactFormHandler();
$handler->handle();
?>