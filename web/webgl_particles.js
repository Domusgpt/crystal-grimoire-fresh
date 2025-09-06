/**
 * Industry-Standard WebGL Particle System
 * High-performance, GPU-accelerated particle rendering
 */
class WebGLParticleSystem {
    constructor(canvas, options = {}) {
        this.canvas = canvas;
        this.gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
        
        if (!this.gl) {
            console.error('WebGL not supported, falling back to Canvas 2D');
            this.fallbackTo2D();
            return;
        }

        // Configuration
        this.config = {
            particleCount: options.particleCount || 20,
            particleSize: options.particleSize || 4.0,
            speed: options.speed || 0.5,
            color: options.color || [0.58, 0.2, 0.91, 0.8], // Purple RGBA
            ...options
        };

        this.particles = [];
        this.startTime = Date.now();
        this.isRunning = false;

        this.initWebGL();
        this.initParticles();
        this.start();
    }

    initWebGL() {
        const gl = this.gl;
        
        // Vertex shader - runs on GPU for each particle
        const vertexShaderSource = `
            attribute vec2 a_position;
            attribute float a_size;
            attribute float a_alpha;
            attribute float a_time;
            
            uniform float u_time;
            uniform vec2 u_resolution;
            
            varying float v_alpha;
            
            void main() {
                // Calculate particle movement over time
                vec2 pos = a_position;
                float timeOffset = a_time;
                
                // Floating movement with time
                pos.y = mod(pos.y + u_time * 0.1 + timeOffset, 2.0) - 1.0;
                pos.x += sin(u_time * 0.5 + timeOffset) * 0.1;
                
                // Convert to clip space
                vec2 clipSpace = ((pos + 1.0) / 2.0) * 2.0 - 1.0;
                gl_Position = vec4(clipSpace, 0.0, 1.0);
                
                // Set point size and alpha
                gl_PointSize = a_size;
                v_alpha = a_alpha;
            }
        `;

        // Fragment shader - runs on GPU for each pixel
        const fragmentShaderSource = `
            precision mediump float;
            
            uniform vec4 u_color;
            varying float v_alpha;
            
            void main() {
                // Create circular particles with glow effect
                vec2 center = gl_PointCoord - vec2(0.5);
                float dist = length(center);
                
                if (dist > 0.5) {
                    discard; // Outside circle
                }
                
                // Soft glow effect
                float alpha = (1.0 - dist * 2.0) * v_alpha;
                gl_FragColor = vec4(u_color.rgb, alpha * u_color.a);
            }
        `;

        // Compile shaders
        this.program = this.createShaderProgram(vertexShaderSource, fragmentShaderSource);
        
        // Get attribute and uniform locations
        this.attribLocations = {
            position: gl.getAttribLocation(this.program, 'a_position'),
            size: gl.getAttribLocation(this.program, 'a_size'),
            alpha: gl.getAttribLocation(this.program, 'a_alpha'),
            time: gl.getAttribLocation(this.program, 'a_time'),
        };
        
        this.uniformLocations = {
            time: gl.getUniformLocation(this.program, 'u_time'),
            resolution: gl.getUniformLocation(this.program, 'u_resolution'),
            color: gl.getUniformLocation(this.program, 'u_color'),
        };

        // Create buffers
        this.buffers = {
            position: gl.createBuffer(),
            size: gl.createBuffer(),
            alpha: gl.createBuffer(),
            time: gl.createBuffer(),
        };

        // Enable blending for transparency
        gl.enable(gl.BLEND);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        
        // Set clear color to transparent
        gl.clearColor(0.0, 0.0, 0.0, 0.0);
    }

    createShaderProgram(vertexSource, fragmentSource) {
        const gl = this.gl;
        
        const vertexShader = this.compileShader(gl.VERTEX_SHADER, vertexSource);
        const fragmentShader = this.compileShader(gl.FRAGMENT_SHADER, fragmentSource);
        
        const program = gl.createProgram();
        gl.attachShader(program, vertexShader);
        gl.attachShader(program, fragmentShader);
        gl.linkProgram(program);
        
        if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
            console.error('Shader program failed to link:', gl.getProgramInfoLog(program));
            return null;
        }
        
        return program;
    }

    compileShader(type, source) {
        const gl = this.gl;
        const shader = gl.createShader(type);
        
        gl.shaderSource(shader, source);
        gl.compileShader(shader);
        
        if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
            console.error('Shader compilation error:', gl.getShaderInfoLog(shader));
            gl.deleteShader(shader);
            return null;
        }
        
        return shader;
    }

    initParticles() {
        this.particles = [];
        
        for (let i = 0; i < this.config.particleCount; i++) {
            this.particles.push({
                x: (Math.random() - 0.5) * 2, // -1 to 1
                y: (Math.random() - 0.5) * 2, // -1 to 1
                size: Math.random() * this.config.particleSize + 2,
                alpha: Math.random() * 0.6 + 0.2,
                timeOffset: Math.random() * Math.PI * 2,
            });
        }

        this.updateBuffers();
    }

    updateBuffers() {
        const gl = this.gl;
        
        // Extract data arrays
        const positions = [];
        const sizes = [];
        const alphas = [];
        const timeOffsets = [];
        
        for (const particle of this.particles) {
            positions.push(particle.x, particle.y);
            sizes.push(particle.size);
            alphas.push(particle.alpha);
            timeOffsets.push(particle.timeOffset);
        }
        
        // Upload to GPU
        gl.bindBuffer(gl.ARRAY_BUFFER, this.buffers.position);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(positions), gl.STATIC_DRAW);
        
        gl.bindBuffer(gl.ARRAY_BUFFER, this.buffers.size);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(sizes), gl.STATIC_DRAW);
        
        gl.bindBuffer(gl.ARRAY_BUFFER, this.buffers.alpha);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(alphas), gl.STATIC_DRAW);
        
        gl.bindBuffer(gl.ARRAY_BUFFER, this.buffers.time);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(timeOffsets), gl.STATIC_DRAW);
    }

    render() {
        if (!this.gl || !this.isRunning) return;
        
        const gl = this.gl;
        
        // Resize canvas if needed
        if (this.canvas.width !== this.canvas.clientWidth || 
            this.canvas.height !== this.canvas.clientHeight) {
            this.canvas.width = this.canvas.clientWidth;
            this.canvas.height = this.canvas.clientHeight;
            gl.viewport(0, 0, this.canvas.width, this.canvas.height);
        }
        
        // Clear canvas
        gl.clear(gl.COLOR_BUFFER_BIT);
        
        // Use shader program
        gl.useProgram(this.program);
        
        // Set uniforms
        const currentTime = (Date.now() - this.startTime) / 1000.0;
        gl.uniform1f(this.uniformLocations.time, currentTime);
        gl.uniform2f(this.uniformLocations.resolution, this.canvas.width, this.canvas.height);
        gl.uniform4fv(this.uniformLocations.color, this.config.color);
        
        // Bind attributes
        this.bindAttribute(this.buffers.position, this.attribLocations.position, 2);
        this.bindAttribute(this.buffers.size, this.attribLocations.size, 1);
        this.bindAttribute(this.buffers.alpha, this.attribLocations.alpha, 1);
        this.bindAttribute(this.buffers.time, this.attribLocations.time, 1);
        
        // Draw particles
        gl.drawArrays(gl.POINTS, 0, this.config.particleCount);
        
        // Continue animation
        requestAnimationFrame(() => this.render());
    }

    bindAttribute(buffer, location, size) {
        const gl = this.gl;
        
        if (location === -1) return;
        
        gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
        gl.enableVertexAttribArray(location);
        gl.vertexAttribPointer(location, size, gl.FLOAT, false, 0, 0);
    }

    start() {
        this.isRunning = true;
        this.render();
    }

    stop() {
        this.isRunning = false;
    }

    updateConfig(newConfig) {
        this.config = { ...this.config, ...newConfig };
        if (newConfig.particleCount && newConfig.particleCount !== this.config.particleCount) {
            this.initParticles();
        }
    }

    // Fallback to Canvas 2D for older browsers
    fallbackTo2D() {
        console.log('Using Canvas 2D fallback');
        this.ctx = this.canvas.getContext('2d');
        this.initParticles();
        this.render2D();
    }

    render2D() {
        if (!this.ctx || !this.isRunning) return;

        const ctx = this.ctx;
        const time = (Date.now() - this.startTime) / 1000.0;

        // Clear canvas
        ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

        // Set blend mode for glow effect
        ctx.globalCompositeOperation = 'screen';

        for (const particle of this.particles) {
            const x = (particle.x + 1) / 2 * this.canvas.width;
            const y = ((particle.y + Math.sin(time + particle.timeOffset) * 0.1) + 1) / 2 * this.canvas.height;

            const gradient = ctx.createRadialGradient(x, y, 0, x, y, particle.size);
            gradient.addColorStop(0, `rgba(148, 51, 234, ${particle.alpha})`);
            gradient.addColorStop(1, 'rgba(148, 51, 234, 0)');

            ctx.fillStyle = gradient;
            ctx.beginPath();
            ctx.arc(x, y, particle.size, 0, Math.PI * 2);
            ctx.fill();
        }

        requestAnimationFrame(() => this.render2D());
    }

    destroy() {
        this.stop();
        if (this.gl) {
            // Clean up WebGL resources
            this.gl.deleteProgram(this.program);
            Object.values(this.buffers).forEach(buffer => this.gl.deleteBuffer(buffer));
        }
    }
}

// Global function to create particle system
window.createWebGLParticles = function(canvasId, options = {}) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) {
        console.error(`Canvas with id '${canvasId}' not found`);
        return null;
    }
    
    return new WebGLParticleSystem(canvas, options);
};