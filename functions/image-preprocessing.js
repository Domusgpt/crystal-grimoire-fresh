/**
 * 🖼️ IMAGE PREPROCESSING & GRID-BASED ANALYSIS
 * Dramatically reduces costs by processing smaller/partial images
 */

const sharp = require('sharp');
const { HttpsError } = require('firebase-functions/v2/https');
const crypto = require('crypto');

// ============================================================================
// IMAGE SIZE LIMITS (Prevent Large Uploads)
// ============================================================================

const IMAGE_LIMITS = {
  free: {
    maxWidth: 512,       // Very small for free tier
    maxHeight: 512,
    quality: 60,         // Lower quality
    maxFileSize: 200000, // 200KB max
    format: 'jpeg'
  },
  premium: {
    maxWidth: 1024,
    maxHeight: 1024,
    quality: 75,
    maxFileSize: 500000, // 500KB max
    format: 'jpeg'
  },
  pro: {
    maxWidth: 2048,
    maxHeight: 2048,
    quality: 85,
    maxFileSize: 1000000, // 1MB max
    format: 'jpeg'
  },
  founders: {
    maxWidth: 4096,      // Full resolution
    maxHeight: 4096,
    quality: 90,
    maxFileSize: 2000000, // 2MB max
    format: 'jpeg'
  }
};

// ============================================================================
// GRID-BASED ANALYSIS STRATEGY
// ============================================================================

/**
 * Extract only the center portion of the image for initial analysis
 * This dramatically reduces processing costs
 */
async function extractCenterGrid(imageBuffer, gridSize = 'small') {
  const image = sharp(imageBuffer);
  const metadata = await image.metadata();

  let extractWidth, extractHeight;

  switch (gridSize) {
    case 'small':   // Free tier - just center 25%
      extractWidth = Math.floor(metadata.width * 0.5);
      extractHeight = Math.floor(metadata.height * 0.5);
      break;
    case 'medium':  // Premium tier - center 50%
      extractWidth = Math.floor(metadata.width * 0.7);
      extractHeight = Math.floor(metadata.height * 0.7);
      break;
    case 'large':   // Pro tier - center 75%
      extractWidth = Math.floor(metadata.width * 0.85);
      extractHeight = Math.floor(metadata.height * 0.85);
      break;
    case 'full':    // Founders tier - full image
      return imageBuffer;
    default:
      extractWidth = Math.floor(metadata.width * 0.5);
      extractHeight = Math.floor(metadata.height * 0.5);
  }

  const left = Math.floor((metadata.width - extractWidth) / 2);
  const top = Math.floor((metadata.height - extractHeight) / 2);

  return await image
    .extract({
      left,
      top,
      width: extractWidth,
      height: extractHeight
    })
    .toBuffer();
}

/**
 * Preprocess image based on user tier
 * Returns: { processedImage: base64, metadata: {...}, cost_tier: 'thumbnail'|'full' }
 */
async function preprocessImage(imageData, userTier = 'free', analysisType = 'initial') {
  try {
    // Validate input
    if (!imageData || typeof imageData !== 'string') {
      throw new HttpsError('invalid-argument', 'Invalid image data');
    }

    // Convert base64 to buffer
    const imageBuffer = Buffer.from(imageData, 'base64');
    const limits = IMAGE_LIMITS[userTier] || IMAGE_LIMITS.free;

    // CRITICAL: Check file size BEFORE processing
    if (imageBuffer.length > limits.maxFileSize) {
      throw new HttpsError(
        'invalid-argument',
        `Image too large. Max ${Math.floor(limits.maxFileSize / 1000)}KB for ${userTier} tier.`
      );
    }

    console.log(`📸 Preprocessing image for ${userTier} tier (${analysisType})`);

    let processedBuffer = imageBuffer;
    let gridSize = 'small';
    let costTier = 'thumbnail';

    // Determine processing strategy
    if (analysisType === 'initial') {
      // Initial analysis - use grid extraction for cost savings
      if (userTier === 'free') {
        gridSize = 'small';    // 25% center area only
        costTier = 'thumbnail';
      } else if (userTier === 'premium') {
        gridSize = 'medium';   // 50% center area
        costTier = 'thumbnail';
      } else if (userTier === 'pro') {
        gridSize = 'large';    // 75% of image
        costTier = 'progressive';
      } else {
        gridSize = 'full';     // Founders get full resolution
        costTier = 'full';
      }

      // Extract center grid
      processedBuffer = await extractCenterGrid(imageBuffer, gridSize);
      console.log(`   ✂️  Extracted ${gridSize} grid for initial analysis`);

    } else if (analysisType === 'progressive') {
      // Progressive analysis - triggered when confidence is low
      // Only for paid tiers
      if (userTier === 'free') {
        throw new HttpsError(
          'permission-denied',
          'Progressive analysis requires premium subscription'
        );
      }

      gridSize = userTier === 'premium' ? 'large' : 'full';
      processedBuffer = await extractCenterGrid(imageBuffer, gridSize);
      costTier = 'progressive';
      console.log(`   🔍 Progressive analysis with ${gridSize} grid`);

    } else if (analysisType === 'full') {
      // Full analysis - only for pro/founders tier
      if (userTier !== 'pro' && userTier !== 'founders') {
        throw new HttpsError(
          'permission-denied',
          'Full resolution analysis requires Pro or Founders subscription'
        );
      }

      gridSize = 'full';
      costTier = 'full';
      console.log(`   🎯 Full resolution analysis`);
    }

    // Resize and compress
    const processed = sharp(processedBuffer);
    const metadata = await processed.metadata();

    const resized = await processed
      .resize(limits.maxWidth, limits.maxHeight, {
        fit: 'inside',        // Maintain aspect ratio
        withoutEnlargement: true
      })
      .jpeg({
        quality: limits.quality,
        progressive: true,
        optimizeScans: true
      })
      .toBuffer();

    const finalMetadata = await sharp(resized).metadata();

    console.log(`   📊 Original: ${metadata.width}x${metadata.height} (${(imageBuffer.length/1024).toFixed(1)}KB)`);
    console.log(`   📊 Processed: ${finalMetadata.width}x${finalMetadata.height} (${(resized.length/1024).toFixed(1)}KB)`);
    console.log(`   💰 Cost tier: ${costTier}, Grid: ${gridSize}`);

    return {
      processedImage: resized.toString('base64'),
      metadata: {
        originalWidth: metadata.width,
        originalHeight: metadata.height,
        processedWidth: finalMetadata.width,
        processedHeight: finalMetadata.height,
        originalSize: imageBuffer.length,
        processedSize: resized.length,
        compressionRatio: ((1 - (resized.length / imageBuffer.length)) * 100).toFixed(1),
        gridSize,
        userTier,
        analysisType
      },
      costTier,
      hash: crypto.createHash('sha256').update(resized).digest('hex').substring(0, 16)
    };

  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    console.error('Image preprocessing error:', error);
    throw new HttpsError('internal', `Image processing failed: ${error.message}`);
  }
}

/**
 * Validate image data before processing
 */
function validateImageData(imageData, userTier = 'free') {
  if (!imageData) {
    throw new HttpsError('invalid-argument', 'Image data is required');
  }

  if (typeof imageData !== 'string') {
    throw new HttpsError('invalid-argument', 'Image data must be base64 string');
  }

  // Remove data URL prefix if present
  let cleanedData = imageData;
  if (imageData.startsWith('data:')) {
    const matches = imageData.match(/^data:image\/[^;]+;base64,(.+)$/);
    if (matches && matches[1]) {
      cleanedData = matches[1];
    } else {
      throw new HttpsError('invalid-argument', 'Invalid data URL format');
    }
  }

  // Basic base64 validation
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(cleanedData)) {
    throw new HttpsError('invalid-argument', 'Invalid base64 encoding');
  }

  // Decode to check size
  const buffer = Buffer.from(cleanedData, 'base64');
  const limits = IMAGE_LIMITS[userTier] || IMAGE_LIMITS.free;

  if (buffer.length > limits.maxFileSize) {
    throw new HttpsError(
      'invalid-argument',
      `Image exceeds ${Math.floor(limits.maxFileSize / 1000)}KB limit for ${userTier} tier. ` +
      `Current size: ${Math.floor(buffer.length / 1000)}KB. ` +
      `Please compress the image or upgrade your plan.`
    );
  }

  if (buffer.length < 100) {
    throw new HttpsError('invalid-argument', 'Image data too small to be valid');
  }

  return cleanedData;
}

/**
 * Calculate confidence threshold for progressive enhancement
 */
function shouldTriggerProgressiveAnalysis(confidence, userTier) {
  // Confidence is 0-1
  const thresholds = {
    free: null,        // Free tier doesn't get progressive analysis
    premium: 0.70,     // Trigger if confidence < 70%
    pro: 0.80,         // Trigger if confidence < 80%
    founders: 0.85     // Trigger if confidence < 85%
  };

  const threshold = thresholds[userTier];
  if (threshold === null) return false;

  return confidence < threshold;
}

/**
 * Get analysis strategy based on tier and confidence
 */
function getAnalysisStrategy(userTier, previousConfidence = null) {
  if (!previousConfidence) {
    // Initial analysis - use grid-based
    return {
      type: 'initial',
      gridSize: userTier === 'free' ? 'small' :
               userTier === 'premium' ? 'medium' :
               userTier === 'pro' ? 'large' : 'full',
      model: userTier === 'pro' || userTier === 'founders' ? 'gemini-1.5-pro' : 'gemini-1.5-flash',
      maxTokens: 1024,
      estimatedCost: userTier === 'free' ? 0.001 :
                    userTier === 'premium' ? 0.002 :
                    userTier === 'pro' ? 0.008 : 0.015
    };
  }

  // Check if progressive analysis is needed
  if (shouldTriggerProgressiveAnalysis(previousConfidence, userTier)) {
    if (userTier === 'free') {
      // Free tier doesn't get progressive - just return low confidence result
      return null;
    }

    return {
      type: 'progressive',
      gridSize: userTier === 'premium' ? 'large' : 'full',
      model: 'gemini-1.5-pro',
      maxTokens: 1536,
      estimatedCost: userTier === 'premium' ? 0.008 : 0.015
    };
  }

  // Confidence is good enough
  return null;
}

/**
 * Create thumbnail for storage/display
 * Very small, used for collection view
 */
async function createThumbnail(imageData, maxSize = 128) {
  try {
    const imageBuffer = Buffer.from(imageData, 'base64');

    const thumbnail = await sharp(imageBuffer)
      .resize(maxSize, maxSize, {
        fit: 'cover',
        position: 'center'
      })
      .jpeg({
        quality: 70,
        progressive: false
      })
      .toBuffer();

    return thumbnail.toString('base64');
  } catch (error) {
    console.error('Thumbnail creation failed:', error);
    return null;
  }
}

module.exports = {
  preprocessImage,
  validateImageData,
  shouldTriggerProgressiveAnalysis,
  getAnalysisStrategy,
  extractCenterGrid,
  createThumbnail,
  IMAGE_LIMITS
};
