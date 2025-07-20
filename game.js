// Love Run - Heart Catching Game
class Game {
    constructor() {
        this.canvas = document.getElementById('gameCanvas');
        this.ctx = this.canvas.getContext('2d');
        this.width = this.canvas.width;
        this.height = this.canvas.height;
        
        // Game state
        this.isRunning = false;
        this.score = 0;
        this.heartsCaught = 0;
        this.gameSpeed = 2;
        
        // Player properties
        this.player = {
            x: 100, // Player position on screen
            y: this.height - 120,
            width: 50,
            height: 70,
            velocityX: 0,
            velocityY: 0,
            isJumping: false,
            jumpPower: 18,
            gravity: 0.8,
            groundY: this.height - 120,
            smileLevel: -1, // Start with frown (-1), then 0-5 levels of happiness
            runCycle: 0, // For running animation
            speed: 5, // Horizontal movement speed
            facing: 1 // 1 for right, -1 for left
        };
        
        // Side-scrolling properties
        this.camera = { x: 0, y: 0 };
        this.worldWidth = 3000; // Total world width
        this.backgroundLayers = [];
        
        // Hearts array
        this.hearts = [];
        this.heartSpawnTimer = 0;
        this.heartSpawnRate = 120; // frames between spawns
        
        // Particles for effects
        this.particles = [];
        
        // Input handling
        this.keys = {};
        this.setupEventListeners();
        
        // Start the game loop
        this.gameLoop();
    }
    
    setupEventListeners() {
        // Keyboard events
        document.addEventListener('keydown', (e) => {
            this.keys[e.code] = true;
            if (e.code === 'Space') {
                e.preventDefault();
                this.jump();
            }
        });
        
        document.addEventListener('keyup', (e) => {
            this.keys[e.code] = false;
        });
        
        // Mouse/touch events for jumping
        this.canvas.addEventListener('click', () => {
            if (this.isRunning) {
                this.jump();
            }
        });
        
        this.canvas.addEventListener('touchstart', (e) => {
            e.preventDefault();
            if (this.isRunning) {
                this.jump();
            }
        });
    }
    
    jump() {
        if (!this.player.isJumping && this.isRunning) {
            this.player.velocityY = -this.player.jumpPower;
            this.player.isJumping = true;
        }
    }
    
    spawnHeart() {
        const heart = {
            x: this.camera.x + this.width + Math.random() * 200, // Spawn ahead of camera
            y: Math.random() * (this.height - 200) + 50, // Random height in upper area
            width: 30,
            height: 30,
            collected: false,
            pulse: 0 // for animation
        };
        this.hearts.push(heart);
    }
    
    createParticle(x, y, color) {
        for (let i = 0; i < 8; i++) {
            this.particles.push({
                x: x,
                y: y,
                velocityX: (Math.random() - 0.5) * 10,
                velocityY: (Math.random() - 0.5) * 10,
                size: Math.random() * 5 + 3,
                color: color,
                life: 30,
                maxLife: 30
            });
        }
    }
    
    updatePlayer() {
        // Handle horizontal movement (arrow keys or WASD)
        this.player.velocityX = 0;
        if ((this.keys['ArrowLeft'] || this.keys['KeyA']) && this.isRunning) {
            this.player.velocityX = -this.player.speed;
            this.player.facing = -1;
        }
        if ((this.keys['ArrowRight'] || this.keys['KeyD']) && this.isRunning) {
            this.player.velocityX = this.player.speed;
            this.player.facing = 1;
        }
        
        // Update running animation when moving
        if (this.player.velocityX !== 0 && !this.player.isJumping) {
            this.player.runCycle += 0.3;
        }
        
        // Apply horizontal movement
        this.player.x += this.player.velocityX;
        
        // Keep player within world bounds
        this.player.x = Math.max(0, Math.min(this.worldWidth - this.player.width, this.player.x));
        
        // Apply gravity and jumping
        if (this.player.isJumping || this.player.y < this.player.groundY) {
            this.player.velocityY += this.player.gravity;
            this.player.y += this.player.velocityY;
            
            // Check if landed
            if (this.player.y >= this.player.groundY) {
                this.player.y = this.player.groundY;
                this.player.velocityY = 0;
                this.player.isJumping = false;
            }
        }
        
        // Update camera to follow player
        const targetCameraX = this.player.x - this.width / 3; // Keep player in left third of screen
        this.camera.x = Math.max(0, Math.min(this.worldWidth - this.width, targetCameraX));
        
        // Update smile level based on hearts caught (start with frown at -1)
        if (this.heartsCaught === 0) {
            this.player.smileLevel = -1; // Frown
        } else {
            this.player.smileLevel = Math.min(5, Math.floor((this.heartsCaught - 1) / 3)); // Smile levels 0-5
        }
    }
    
    updateHearts() {
        this.heartSpawnTimer++;
        if (this.heartSpawnTimer >= this.heartSpawnRate) {
            this.spawnHeart();
            this.heartSpawnTimer = 0;
            // Gradually increase spawn rate
            this.heartSpawnRate = Math.max(60, this.heartSpawnRate - 1);
        }
        
        // Update existing hearts
        for (let i = this.hearts.length - 1; i >= 0; i--) {
            const heart = this.hearts[i];
            heart.pulse += 0.2;
            
            // Check collision with player (world coordinates)
            if (!heart.collected && 
                heart.x < this.player.x + this.player.width &&
                heart.x + heart.width > this.player.x &&
                heart.y < this.player.y + this.player.height &&
                heart.y + heart.height > this.player.y) {
                
                heart.collected = true;
                this.heartsCaught++;
                this.score += 100;
                this.createParticle(heart.x + heart.width/2, heart.y + heart.height/2, '#ff69b4');
                this.hearts.splice(i, 1);
                
                // Update UI
                document.getElementById('score').textContent = this.score;
                document.getElementById('heartsCaught').textContent = this.heartsCaught;
            }
            // Remove hearts that are far behind the camera
            else if (heart.x < this.camera.x - 100) {
                this.hearts.splice(i, 1);
            }
        }
    }
    
    updateParticles() {
        for (let i = this.particles.length - 1; i >= 0; i--) {
            const particle = this.particles[i];
            particle.x += particle.velocityX;
            particle.y += particle.velocityY;
            particle.velocityY += 0.3; // gravity
            particle.life--;
            
            if (particle.life <= 0) {
                this.particles.splice(i, 1);
            }
        }
    }
    
    drawPlayer() {
        const ctx = this.ctx;
        const p = this.player;
        
        // Convert world coordinates to screen coordinates
        const screenX = p.x - this.camera.x;
        const screenY = p.y;
        
        // Save context for transformations
        ctx.save();
        
        // Flip horizontally if facing left
        if (p.facing === -1) {
            ctx.scale(-1, 1);
            ctx.translate(-screenX - p.width, 0);
        } else {
            ctx.translate(screenX, 0);
        }
        
        // Draw body (simple circle)
        ctx.fillStyle = '#fdbcb4';
        ctx.beginPath();
        ctx.arc(p.width/2, screenY + p.height/2, p.width/2, 0, Math.PI * 2);
        ctx.fill();
        
        // Draw eyes
        ctx.fillStyle = '#000';
        ctx.beginPath();
        ctx.arc(p.width/2 - 8, screenY + p.height/2 - 8, 3, 0, Math.PI * 2);
        ctx.fill();
        ctx.beginPath();
        ctx.arc(p.width/2 + 8, screenY + p.height/2 - 8, 3, 0, Math.PI * 2);
        ctx.fill();
        
        // Draw expression based on smile level
        ctx.strokeStyle = '#000';
        ctx.lineWidth = 3;
        ctx.beginPath();
        
        if (p.smileLevel === -1) {
            // Draw frown
            ctx.arc(p.width/2, screenY + p.height/2 + 15, 8, Math.PI + 0.3, Math.PI * 2 - 0.3);
        } else {
            // Draw smile - gets bigger based on hearts caught
            const smileWidth = 10 + (p.smileLevel * 5);
            const smileHeight = 3 + (p.smileLevel * 2);
            ctx.arc(p.width/2, screenY + p.height/2 + 5, smileWidth, 0.2, Math.PI - 0.2);
        }
        ctx.stroke();
        
        // Draw running legs animation
        if (p.velocityX !== 0 && !p.isJumping) {
            const legOffset = Math.sin(p.runCycle) * 5;
            ctx.strokeStyle = '#fdbcb4';
            ctx.lineWidth = 4;
            ctx.beginPath();
            ctx.moveTo(p.width/2 - 5, screenY + p.height - 5);
            ctx.lineTo(p.width/2 - 5 + legOffset, screenY + p.height + 10);
            ctx.moveTo(p.width/2 + 5, screenY + p.height - 5);
            ctx.lineTo(p.width/2 + 5 - legOffset, screenY + p.height + 10);
            ctx.stroke();
        }
        
        ctx.restore();
        
        // Draw happiness sparkles around head when smile level is high
        if (p.smileLevel >= 3) {
            ctx.fillStyle = '#ffff00';
            for (let i = 0; i < p.smileLevel; i++) {
                const angle = (Date.now() / 500 + i * Math.PI/3) % (Math.PI * 2);
                const sparkleX = screenX + p.width/2 + Math.cos(angle) * (p.width/2 + 15);
                const sparkleY = screenY + p.height/2 + Math.sin(angle) * (p.width/2 + 15);
                
                ctx.beginPath();
                ctx.arc(sparkleX, sparkleY, 2, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }
    
    drawHearts() {
        for (const heart of this.hearts) {
            // Convert world coordinates to screen coordinates
            const screenX = heart.x - this.camera.x;
            const screenY = heart.y;
            
            // Only draw hearts that are visible on screen
            if (screenX > -heart.width && screenX < this.width) {
                const size = heart.width + Math.sin(heart.pulse) * 3;
                this.drawHeart(screenX, screenY, size, '#ff1493');
            }
        }
    }
    
    drawHeart(x, y, size, color) {
        const ctx = this.ctx;
        ctx.fillStyle = color;
        ctx.beginPath();
        
        // Heart shape using bezier curves
        const centerX = x + size/2;
        const centerY = y + size/2;
        
        ctx.moveTo(centerX, centerY + size/4);
        ctx.bezierCurveTo(centerX, centerY, centerX - size/2, centerY - size/2, centerX - size/4, centerY - size/2);
        ctx.bezierCurveTo(centerX, centerY - size/2, centerX + size/2, centerY - size/2, centerX + size/4, centerY - size/2);
        ctx.bezierCurveTo(centerX + size/2, centerY - size/2, centerX, centerY, centerX, centerY + size/4);
        
        ctx.fill();
        
        // Add shine effect
        ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
        ctx.beginPath();
        ctx.arc(centerX - size/6, centerY - size/6, size/8, 0, Math.PI * 2);
        ctx.fill();
    }
    
    drawParticles() {
        for (const particle of this.particles) {
            // Convert world coordinates to screen coordinates
            const screenX = particle.x - this.camera.x;
            if (screenX > -10 && screenX < this.width + 10) {
                const alpha = particle.life / particle.maxLife;
                this.ctx.fillStyle = particle.color + Math.floor(alpha * 255).toString(16).padStart(2, '0');
                this.ctx.beginPath();
                this.ctx.arc(screenX, particle.y, particle.size, 0, Math.PI * 2);
                this.ctx.fill();
            }
        }
    }
    
    drawBackground() {
        // Sky gradient
        const gradient = this.ctx.createLinearGradient(0, 0, 0, this.height);
        gradient.addColorStop(0, '#87CEEB');
        gradient.addColorStop(1, '#98FB98');
        this.ctx.fillStyle = gradient;
        this.ctx.fillRect(0, 0, this.width, this.height);
        
        // Simple clouds
        this.ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
        this.drawCloud(100, 80, 60);
        this.drawCloud(300, 120, 80);
        this.drawCloud(600, 60, 50);
        
        // Ground
        this.ctx.fillStyle = '#90EE90';
        this.ctx.fillRect(0, this.height - 30, this.width, 30);
    }
    
    drawCloud(x, y, size) {
        const ctx = this.ctx;
        ctx.beginPath();
        ctx.arc(x, y, size/2, 0, Math.PI * 2);
        ctx.arc(x + size/2, y, size/3, 0, Math.PI * 2);
        ctx.arc(x + size, y, size/2, 0, Math.PI * 2);
        ctx.arc(x + size/4, y - size/3, size/3, 0, Math.PI * 2);
        ctx.arc(x + size * 3/4, y - size/3, size/3, 0, Math.PI * 2);
        ctx.fill();
    }
    
    draw() {
        // Clear canvas
        this.ctx.clearRect(0, 0, this.width, this.height);
        
        // Draw everything
        this.drawBackground();
        this.drawHearts();
        this.drawParticles();
        this.drawPlayer();
        
        // Draw game over or pause screen
        if (!this.isRunning) {
            this.ctx.fillStyle = 'rgba(0, 0, 0, 0.5)';
            this.ctx.fillRect(0, 0, this.width, this.height);
            
            this.ctx.fillStyle = 'white';
            this.ctx.font = '48px Arial';
            this.ctx.textAlign = 'center';
            this.ctx.fillText('Game Paused', this.width/2, this.height/2);
            this.ctx.font = '24px Arial';
            this.ctx.fillText('Click "Start Game" to begin!', this.width/2, this.height/2 + 50);
        }
    }
    
    update() {
        if (!this.isRunning) return;
        
        this.updatePlayer();
        this.updateHearts();
        this.updateParticles();
    }
    
    gameLoop() {
        this.update();
        this.draw();
        requestAnimationFrame(() => this.gameLoop());
    }
    
    start() {
        this.isRunning = true;
        document.getElementById('startButton').textContent = 'Restart Game';
    }
    
    reset() {
        this.score = 0;
        this.heartsCaught = 0;
        this.hearts = [];
        this.particles = [];
        this.heartSpawnTimer = 0;
        this.heartSpawnRate = 120;
        this.player.y = this.player.groundY;
        this.player.velocityY = 0;
        this.player.isJumping = false;
        this.player.smileLevel = 0;
        
        document.getElementById('score').textContent = '0';
        document.getElementById('heartsCaught').textContent = '0';
    }
}

// Initialize game
let game;

function startGame() {
    if (!game) {
        game = new Game();
    } else {
        game.reset();
    }
    game.start();
}

// Initialize the game object when page loads
window.addEventListener('load', () => {
    game = new Game();
});
