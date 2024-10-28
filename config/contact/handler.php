# /config/contact/handler.php
<?php
declare(strict_types=1);
error_reporting(E_ALL);
ini_set('display_errors', '0');

class ContactFormException extends Exception {}

class ContactForm {
    private string $configFile;
    private array $config;
    private string $logFile;
    private string $rateFile;
    
    public function __construct() {
        $this->configFile = dirname(__DIR__) . '/config/contact.json';
        $this->logFile = dirname(__DIR__) . '/logs/contact.log';
        $this->rateFile = dirname(__DIR__) . '/tmp/rate_limit.json';
        $this->config = $this->loadConfig();
        
        // Ensure required directories exist
        $this->ensureDirectories();
    }
    
    private function ensureDirectories(): void {
        $dirs = [
            dirname($this->logFile),
            dirname($this->rateFile)
        ];
        
        foreach ($dirs as $dir) {
            if (!is_dir($dir)) {
                mkdir($dir, 0750, true);
            }
        }
    }
    
    private function loadConfig(): array {
        if (!file_exists($this->configFile)) {
            throw new ContactFormException('Configuration file not found');
        }
        
        $config = json_decode(file_get_contents($this->configFile), true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new ContactFormException('Invalid configuration format');
        }
        
        return $config;
    }
    
    private function validateOrigin(): void {
        $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
        if (!in_array($origin, $this->config['allowed_origins'], true)) {
            throw new ContactFormException('Invalid origin', 403);
        }
        header('Access-Control-Allow-Origin: ' . $origin);
    }
    
    private function validateToken(): void {
        if (empty($_POST['csrf_token']) || empty($_SESSION['csrf_token']) ||
            !hash_equals($_SESSION['csrf_token'], $_POST['csrf_token'])) {
            throw new ContactFormException('Invalid security token', 403);
        }
    }
    
    private function checkRateLimit(): void {
        $ip = $_SERVER['REMOTE_ADDR'];
        $now = time();
        $rateLimits = [];
        
        if (file_exists($this->rateFile)) {
            $rateLimits = json_decode(file_get_contents($this->rateFile), true);
        }
        
        // Clean old entries
        foreach ($rateLimits as $checkIp => $timestamps) {
            $rateLimits[$checkIp] = array_filter($timestamps, function($ts) use ($now) {
                return $ts > ($now - 3600);
            });
        }
        
        if (isset($rateLimits[$ip]) && 
            count($rateLimits[$ip]) >= $this->config['max_requests_per_hour']) {
            throw new ContactFormException('Rate limit exceeded', 429);
        }
        
        $rateLimits[$ip][] = $now;
        file_put_contents($this->rateFile, json_encode($rateLimits));
    }
    
    private function validateInput(): array {
        // Check honeypot
        if (!empty($_POST['website'])) {
            throw new ContactFormException('Invalid form submission', 400);
        }
        
        // Required fields
        $required = ['name', 'email', 'message'];
        foreach ($required as $field) {
            if (empty($_POST[$field])) {
                throw new ContactFormException("Missing required field: {$field}", 400);
            }
        }
        
        // Validate email
        if (!filter_var($_POST['email'], FILTER_VALIDATE_EMAIL)) {
            throw new ContactFormException('Invalid email format', 400);
        }
        
        // Validate message length
        if (mb_strlen($_POST['message']) > $this->config['max_message_length']) {
            throw new ContactFormException('Message too long', 400);
        }
        
        return [
            'name' => $this->sanitizeInput($_POST['name']),
            'email' => $this->sanitizeInput($_POST['email']),
            'message' => $this->sanitizeInput($_POST['message'])
        ];
    }
    
    private function sanitizeInput(string $input): string {
        return htmlspecialchars(trim($input), ENT_QUOTES, 'UTF-8');
    }
    
    private function sendEmail(array $data): void {
        $to = $this->config['recipient_email'];
        $subject = $this->config['subject_prefix'] . ' ' . $data['name'];
        
        $message = "Name: {$data['name']}\n";
        $message .= "Email: {$data['email']}\n\n";
        $message .= "Message:\n{$data['message']}\n\n";
        $message .= "---\n";
        $message .= "Sent from: {$_SERVER['REMOTE_ADDR']}\n";
        $message .= "Date: " . date('Y-m-d H:i:s') . "\n";
        
        $headers = [
            'From' => $this->config['from_email'],
            'Reply-To' => $data['email'],
            'X-Mailer' => 'PHP/' . PHP_VERSION,
            'Content-Type' => 'text/plain; charset=UTF-8',
            'X-Contact-Form' => 'yes'
        ];
        
        if (!mail($to, $subject, $message, $headers)) {
            throw new ContactFormException('Failed to send email');
        }
    }
    
    private function logMessage(array $data): void {
        $logEntry = [
            'timestamp' => date('Y-m-d H:i:s'),
            'ip' => $_SERVER['REMOTE_ADDR'],
            'data' => $data
        ];
        
        file_put_contents(
            $this->logFile,
            json_encode($logEntry) . "\n",
            FILE_APPEND | LOCK_EX
        );
    }
    
    public function handleRequest(): void {
        try {
            session_start();
            
            // Handle preflight requests
            if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
                $this->handlePreflight();
                return;
            }
            
            // Handle GET requests (CSRF token)
            if ($_SERVER['REQUEST_METHOD'] === 'GET') {
                $this->handleGet();
                return;
            }
            
            // Handle POST requests (form submission)
            if ($_SERVER['REQUEST_METHOD'] === 'POST') {
                $this->validateOrigin();
                $this->validateToken();
                $this->checkRateLimit();
                
                $data = $this->validateInput();
                $this->sendEmail($data);
                $this->logMessage($data);
                
                $this->sendResponse(['success' => true]);
                return;
            }
            
            throw new ContactFormException('Invalid request method', 405);
            
        } catch (ContactFormException $e) {
            $this->sendResponse(['error' => $e->getMessage()], $e->getCode() ?: 400);
        } catch (Exception $e) {
            error_log("Contact form error: " . $e->getMessage());
            $this->sendResponse(['error' => 'An error occurred'], 500);
        }
    }
    
    private function handlePreflight(): void {
        header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
        header('Access-Control-Allow-Headers: Content-Type, X-CSRF-Token');
        header('Access-Control-Max-Age: 86400');
        exit;
    }
    
    private function handleGet(): void {
        if (empty($_SESSION['csrf_token'])) {
            $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
        }
        $this->sendResponse(['csrf_token' => $_SESSION['csrf_token']]);
    }
    
    private function sendResponse(array $data, int $code = 200): void {
        http_response_code($code);
        header('Content-Type: application/json');
        echo json_encode($data);
        exit;
    }
}

// Initialize and handle request
$contactForm = new ContactForm();
$contactForm->handleRequest();