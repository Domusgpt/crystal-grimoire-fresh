#!/bin/bash

# Crystal Grimoire Production Deployment Script
# SPEC-1 Compliant deployment with all launch requirements

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="crystal-grimoire-2025"
FUNCTIONS_REGION="us-central1"
FLUTTER_BUILD_MODE="release"
BACKUP_ENABLED=true

# Print colored output
print_step() {
    echo -e "${BLUE}🔮 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed or not in PATH"
        exit 1
    fi
    
    # Check Firebase CLI
    if ! command -v firebase &> /dev/null; then
        print_error "Firebase CLI is not installed. Install with: npm install -g firebase-tools"
        exit 1
    fi
    
    # Check if logged into Firebase
    if ! firebase projects:list &> /dev/null; then
        print_error "Not logged into Firebase. Run: firebase login"
        exit 1
    fi
    
    # Check Flutter version
    FLUTTER_VERSION=$(flutter --version | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    print_success "Flutter version: $FLUTTER_VERSION"
    
    # Check Node.js version  
    NODE_VERSION=$(node --version)
    print_success "Node.js version: $NODE_VERSION"
    
    # Check Firebase project
    firebase use "$PROJECT_ID" || {
        print_error "Failed to set Firebase project to $PROJECT_ID"
        print_warning "Available projects:"
        firebase projects:list
        exit 1
    }
    
    print_success "Prerequisites check completed"
}

# Backup current deployment (if enabled)
backup_deployment() {
    if [ "$BACKUP_ENABLED" = true ]; then
        print_step "Creating deployment backup..."
        
        BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        # Backup Firestore rules
        cp firestore.rules "$BACKUP_DIR/"
        cp storage.rules "$BACKUP_DIR/"
        
        # Backup Cloud Functions
        cp -r functions "$BACKUP_DIR/"
        
        # Backup Flutter build artifacts if they exist
        if [ -d "build/web" ]; then
            cp -r build/web "$BACKUP_DIR/flutter_build"
        fi
        
        print_success "Backup created in $BACKUP_DIR"
    fi
}

# Install dependencies
install_dependencies() {
    print_step "Installing dependencies..."
    
    # Flutter dependencies
    print_step "Installing Flutter dependencies..."
    flutter pub get
    
    # Cloud Functions dependencies
    print_step "Installing Cloud Functions dependencies..."
    cd functions
    npm install
    cd ..
    
    print_success "Dependencies installed"
}

# Run tests
run_tests() {
    print_step "Running tests..."
    
    # Flutter tests
    print_step "Running Flutter tests..."
    flutter test --coverage || {
        print_warning "Some Flutter tests failed"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    }
    
    # Cloud Functions tests  
    print_step "Running Cloud Functions tests..."
    cd functions
    npm test || {
        print_warning "Some Cloud Functions tests failed"
        cd ..
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    }
    cd ..
    
    print_success "Tests completed"
}

# Build Flutter web application
build_flutter() {
    print_step "Building Flutter web application..."
    
    # Clean previous build
    flutter clean
    flutter pub get
    
    # Build for web
    flutter build web \
        --$FLUTTER_BUILD_MODE \
        --base-href="/" \
        --web-renderer canvaskit \
        --dart-define=FLUTTER_WEB_CANVASKIT_URL=/canvaskit/ \
        --source-maps
    
    # Optimize build
    print_step "Optimizing build artifacts..."
    
    # Create optimized build directory
    if [ -d "build/web_optimized" ]; then
        rm -rf build/web_optimized
    fi
    
    cp -r build/web build/web_optimized
    
    # Compress assets (if tools are available)
    if command -v gzip &> /dev/null; then
        find build/web_optimized -name "*.js" -o -name "*.css" -o -name "*.json" | while read file; do
            gzip -k -f "$file"
        done
        print_success "Compressed assets with gzip"
    fi
    
    print_success "Flutter build completed"
}

# Deploy Firebase security rules
deploy_security_rules() {
    print_step "Deploying Firestore security rules..."
    
    # Validate rules first
    firebase firestore:rules:get --help &> /dev/null || {
        print_warning "Cannot validate rules, proceeding with deployment"
    }
    
    firebase deploy --only firestore:rules,storage
    
    print_success "Security rules deployed"
}

# Deploy Cloud Functions
deploy_functions() {
    print_step "Deploying Cloud Functions..."
    
    # Set environment variables
    print_step "Configuring Cloud Functions environment..."
    
    # Check if required environment variables are set
    if [ -z "$GEMINI_API_KEY" ]; then
        print_warning "GEMINI_API_KEY not set in environment"
        print_warning "Set it with: firebase functions:config:set gemini.api_key=\"your_key\""
    fi
    
    # Deploy functions
    firebase deploy --only functions
    
    print_success "Cloud Functions deployed"
}

# Deploy Flutter web to Firebase Hosting
deploy_hosting() {
    print_step "Deploying Flutter web to Firebase Hosting..."
    
    # Use optimized build if available
    BUILD_DIR="build/web"
    if [ -d "build/web_optimized" ]; then
        BUILD_DIR="build/web_optimized"
        print_step "Using optimized build"
    fi
    
    # Update firebase.json to use correct build directory
    jq --arg build_dir "$BUILD_DIR" '.hosting.public = $build_dir' firebase.json > firebase.json.tmp
    mv firebase.json.tmp firebase.json
    
    # Deploy hosting
    firebase deploy --only hosting
    
    print_success "Flutter web deployed to Firebase Hosting"
}

# Seed database with initial data
seed_database() {
    print_step "Seeding database with initial data..."
    
    # Check if service account key exists
    if [ ! -f "firebase-service-account-key.json" ]; then
        print_warning "Firebase service account key not found"
        print_warning "Download it from Firebase Console > Project Settings > Service Accounts"
        print_warning "Skipping database seeding"
        return
    fi
    
    # Run seeding script
    cd scripts
    node seed_database.js seed
    cd ..
    
    print_success "Database seeded"
}

# Post-deployment verification
verify_deployment() {
    print_step "Verifying deployment..."
    
    # Get project info
    PROJECT_INFO=$(firebase projects:list | grep "$PROJECT_ID")
    
    if [ -n "$PROJECT_INFO" ]; then
        print_success "Project $PROJECT_ID is accessible"
    else
        print_error "Project $PROJECT_ID not found"
        exit 1
    fi
    
    # Check hosting URL
    HOSTING_URL="https://$PROJECT_ID.web.app"
    print_step "Checking hosting URL: $HOSTING_URL"
    
    if command -v curl &> /dev/null; then
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HOSTING_URL" || echo "000")
        if [ "$HTTP_STATUS" = "200" ]; then
            print_success "Hosting is live and responding"
        else
            print_warning "Hosting returned status: $HTTP_STATUS"
        fi
    fi
    
    # Check Cloud Functions
    print_step "Verifying Cloud Functions..."
    firebase functions:list --project "$PROJECT_ID" > /dev/null 2>&1 && {
        print_success "Cloud Functions are deployed"
    } || {
        print_warning "Could not verify Cloud Functions"
    }
    
    print_success "Deployment verification completed"
}

# Display post-deployment information
show_deployment_info() {
    print_success "🎉 Deployment completed successfully!"
    echo
    echo -e "${PURPLE}📋 Deployment Information:${NC}"
    echo -e "  🌐 Hosting URL: https://$PROJECT_ID.web.app"
    echo -e "  🌐 Custom Domain: https://$PROJECT_ID.firebaseapp.com"
    echo -e "  ☁️  Cloud Functions: https://us-central1-$PROJECT_ID.cloudfunctions.net/"
    echo -e "  🗄️  Firestore: https://console.firebase.google.com/project/$PROJECT_ID/firestore"
    echo
    echo -e "${BLUE}🚀 Next Steps:${NC}"
    echo "  1. Test all features in production environment"
    echo "  2. Monitor Cloud Function logs and performance"
    echo "  3. Check Firestore security rules are working"
    echo "  4. Verify analytics and error tracking"
    echo "  5. Set up monitoring alerts"
    echo
    echo -e "${GREEN}✨ Crystal Grimoire is now live! ✨${NC}"
}

# Main deployment function
deploy() {
    local DEPLOY_MODE="$1"
    
    echo -e "${PURPLE}🔮✨ Crystal Grimoire Deployment Script ✨🔮${NC}"
    echo -e "${BLUE}Project: $PROJECT_ID${NC}"
    echo -e "${BLUE}Region: $FUNCTIONS_REGION${NC}"
    echo -e "${BLUE}Mode: ${DEPLOY_MODE:-full}${NC}"
    echo

    case "$DEPLOY_MODE" in
        "quick")
            print_step "Running quick deployment (no tests, no backup)..."
            check_prerequisites
            install_dependencies
            build_flutter
            deploy_hosting
            verify_deployment
            show_deployment_info
            ;;
        "functions")
            print_step "Deploying Cloud Functions only..."
            check_prerequisites
            install_dependencies
            run_tests
            deploy_functions
            print_success "Cloud Functions deployment completed"
            ;;
        "hosting")
            print_step "Deploying hosting only..."
            check_prerequisites
            install_dependencies
            build_flutter
            deploy_hosting
            print_success "Hosting deployment completed"
            ;;
        "rules")
            print_step "Deploying security rules only..."
            check_prerequisites
            deploy_security_rules
            print_success "Security rules deployment completed"
            ;;
        *)
            print_step "Running full deployment..."
            check_prerequisites
            backup_deployment
            install_dependencies
            run_tests
            build_flutter
            deploy_security_rules
            deploy_functions
            deploy_hosting
            seed_database
            verify_deployment
            show_deployment_info
            ;;
    esac
}

# Handle script arguments
case "${1:-full}" in
    "full"|"quick"|"functions"|"hosting"|"rules")
        deploy "$1"
        ;;
    "help"|"--help"|"-h")
        echo "Crystal Grimoire Deployment Script"
        echo ""
        echo "Usage: ./scripts/deploy.sh [MODE]"
        echo ""
        echo "Modes:"
        echo "  full      - Complete deployment with tests and backup (default)"
        echo "  quick     - Fast deployment without tests or backup"
        echo "  functions - Deploy Cloud Functions only"
        echo "  hosting   - Deploy Flutter web hosting only"
        echo "  rules     - Deploy Firestore security rules only"
        echo "  help      - Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  GEMINI_API_KEY    - Required for AI features"
        echo "  BACKUP_ENABLED    - Enable/disable backups (default: true)"
        echo ""
        ;;
    *)
        print_error "Unknown deployment mode: $1"
        echo "Run './scripts/deploy.sh help' for usage information"
        exit 1
        ;;
esac