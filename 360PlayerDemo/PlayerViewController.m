//
//  PlayerViewController.m
//  360PlayerDemo
//
//  Created by heyunpeng on 16/5/8.
//  Copyright © 2016年 heyunpeng. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PlayerViewController.h"
#import "OpenGLProgram.h"
#import "ViewController.h"
#import <CoreMotion/CoreMotion.h>

static const GLfloat kColorConversion[] = {
    1.164,  1.164, 1.164,
    0.0, -0.213, 2.112,
    1.793, -0.533,   0.0,
};

enum {
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_Y,
    UNIFORM_UV,
    UNIFORM_COLOR_CONVERSION_MATRIX,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];


@interface VideoPlayerViewController () {
    GLKMatrix4 modelViewProjectionMatrix;
    
    GLuint vertexArrayID;
    GLuint vertexBufferID;
    GLuint vertexIndicesBufferID;
    GLuint vertexTexCoordID;
    GLuint vertexTexCoordAttributeIndex;
    
    float fingerRotationX;
    float fingerRotationY;
    CGFloat overture;
    
    int numIndices;
    
    CMMotionManager *motionManager;
    CMAttitude *referenceAttitude;
    
    CVOpenGLESTextureRef lumaTexture;
    CVOpenGLESTextureRef chromaTexture;
    CVOpenGLESTextureCacheRef videoTextureCache;
    
    const GLfloat *preferredConversion;
}

@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) OpenGLProgram *program;
@property (strong, nonatomic) NSMutableArray *currentTouches;

@end

@implementation VideoPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    UIPinchGestureRecognizer *pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    [view addGestureRecognizer:pinchRecognizer];
    
    self.preferredFramesPerSecond = 30.0f;
    
    overture = 85.0;
    preferredConversion = kColorConversion;
    
    [self initOpenGL];
    
    motionManager = [[CMMotionManager alloc] init];
    referenceAttitude = nil;
    motionManager.deviceMotionUpdateInterval = 1.0 / 60.0;
    motionManager.gyroUpdateInterval = 1.0f / 60;
    motionManager.showsDeviceMovementDisplay = YES;
    
    [motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical];
    
    referenceAttitude = motionManager.deviceMotion.attitude;
}

- (void)dealloc {
    [motionManager stopDeviceMotionUpdates];
    motionManager = nil;
    
    glDeleteBuffers(1, &vertexBufferID);
    glDeleteVertexArraysOES(1, &vertexArrayID);
    glDeleteBuffers(1, &vertexTexCoordID);
    
    _program = nil;
    videoTextureCache = nil;
    [EAGLContext setCurrentContext:nil];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
int genSphere(int numSlices, float radius, float **vertices, float **normals, float **texCoords, uint16_t **indices, int *numVertices_out) {
    int numParallels = numSlices / 2;
    int numVertices = ( numParallels + 1 ) * ( numSlices + 1 );
    int numIndices = numParallels * numSlices * 6;
    float angleStep = (2.0f * 3.14159265f) / ((float) numSlices);
    
    if (vertices != NULL)
        *vertices = malloc (sizeof(float) * 3 * numVertices);
    
    if (texCoords != NULL)
        *texCoords = malloc(sizeof(float) * 2 * numVertices);
    
    if (indices != NULL)
        *indices = malloc ( sizeof(uint16_t) * numIndices);
    
    for (int i = 0; i < numParallels + 1; i++) {
        for (int j = 0; j < numSlices + 1; j++) {
            int vertex = (i * (numSlices + 1) + j) * 3;
            
            if (vertices) {
                (*vertices)[vertex + 0] = radius * sinf ( angleStep * (float)i ) *
                sinf ( angleStep * (float)j );
                (*vertices)[vertex + 1] = radius * cosf ( angleStep * (float)i );
                (*vertices)[vertex + 2] = radius * sinf ( angleStep * (float)i ) *
                cosf ( angleStep * (float)j );
            }
            
            if (texCoords) {
                int texIndex = ( i * (numSlices + 1) + j ) * 2;
                (*texCoords)[texIndex + 0] = (float) j / (float) numSlices;
                (*texCoords)[texIndex + 1] = 1.0f - ((float) i / (float) (numParallels));
            }
        }
    }
    
    if (indices != NULL) {
        uint16_t *indexBuf = (*indices);
        for (int i = 0; i < numParallels ; i++ ) {
            for (int j = 0; j < numSlices; j++ ) {
                *indexBuf++  = i * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + ( j + 1 );
                
                *indexBuf++ = i * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + ( j + 1 );
                *indexBuf++ = i * ( numSlices + 1 ) + ( j + 1 );
            }
        }
    }
    
    if (numVertices_out) {
        *numVertices_out = numVertices;
    }
    
    return numIndices;
}
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)initOpenGL {
    [EAGLContext setCurrentContext:self.context];
    
    [self buildProgram];
    
    GLfloat *vVertices = NULL;
    GLfloat *vTextCoord = NULL;
    GLushort *indices = NULL;
    int numVertices = 0;
    numIndices = genSphere(200, 1.0f, &vVertices,  NULL, &vTextCoord, &indices, &numVertices);
    
    glGenVertexArraysOES(1, &vertexArrayID);
    glBindVertexArrayOES(vertexArrayID);
    
    glGenBuffers(1, &vertexBufferID);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBufferID);
    glBufferData(GL_ARRAY_BUFFER, numVertices*3*sizeof(GLfloat), vVertices, GL_STATIC_DRAW);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 3, NULL);
    
    glGenBuffers(1, &vertexTexCoordID);
    glBindBuffer(GL_ARRAY_BUFFER, vertexTexCoordID);
    glBufferData(GL_ARRAY_BUFFER, numVertices*2*sizeof(GLfloat), vTextCoord, GL_DYNAMIC_DRAW);
    glEnableVertexAttribArray(vertexTexCoordAttributeIndex);
    glVertexAttribPointer(vertexTexCoordAttributeIndex, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 2, NULL);
    
    glGenBuffers(1, &vertexIndicesBufferID);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vertexIndicesBufferID);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(GLushort) * numIndices, indices, GL_STATIC_DRAW);
    
    if (!videoTextureCache) {
        CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &videoTextureCache);
    }
    
    [_program use];
    
    glUniform1i(uniforms[UNIFORM_Y], 0);
    glUniform1i(uniforms[UNIFORM_UV], 1);
    glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, preferredConversion);
}

- (void)cleanUpTextures {
    if (lumaTexture) {
        CFRelease(lumaTexture);
        lumaTexture = NULL;
    }
    
    if (chromaTexture) {
        CFRelease(chromaTexture);
        chromaTexture = NULL;
    }
    
    CVOpenGLESTextureCacheFlush(videoTextureCache, 0);
}

- (void)update {
    float aspect = fabs(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(overture), aspect, 0.1f, 400.0f);
    projectionMatrix = GLKMatrix4Rotate(projectionMatrix, 3.14159265f, 1.0f, 0.0f, 0.0f);
    
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, 300.0, 300.0, 300.0);
    modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, fingerRotationX);
    modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, fingerRotationY);
    
    modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [_program use];
    
    glBindVertexArrayOES(vertexArrayID);
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, modelViewProjectionMatrix.m);
    CVPixelBufferRef pixelBuffer = [self.videoPlayerController getPixelBuffer];
    
    if (pixelBuffer != NULL) {
        int frameWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
        int frameHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
        
        [self cleanUpTextures];
        
        glActiveTexture(GL_TEXTURE0);
        CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, videoTextureCache, pixelBuffer, NULL,
                                                     GL_TEXTURE_2D, GL_RED_EXT, frameWidth, frameHeight, GL_RED_EXT,
                                                     GL_UNSIGNED_BYTE,0, &lumaTexture);
        
        glBindTexture(CVOpenGLESTextureGetTarget(lumaTexture), CVOpenGLESTextureGetName(lumaTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glActiveTexture(GL_TEXTURE1);
        CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, videoTextureCache, pixelBuffer, NULL,
                                                     GL_TEXTURE_2D, GL_RG_EXT, frameWidth/2, frameHeight/2, GL_RG_EXT,
                                                     GL_UNSIGNED_BYTE, 1, &chromaTexture);
        
        glBindTexture(CVOpenGLESTextureGetTarget(chromaTexture), CVOpenGLESTextureGetName(chromaTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        CFRelease(pixelBuffer);
        
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        glDrawElements(GL_TRIANGLES, numIndices, GL_UNSIGNED_SHORT, 0);
    }
}

- (void)buildProgram {
    _program = [[OpenGLProgram alloc] initWithVertexFilepath:@"Shader" fragmentShaderFilename:@"Shader"];
    
    [_program addAttribute:@"position"];
    [_program addAttribute:@"texCoord"];
    [_program link];
    
    vertexTexCoordAttributeIndex = [_program attributeIndex:@"texCoord"];
    
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = [_program uniformIndex:@"modelViewProjectionMatrix"];
    uniforms[UNIFORM_Y] = [_program uniformIndex:@"SamplerY"];
    uniforms[UNIFORM_UV] = [_program uniformIndex:@"SamplerUV"];
    uniforms[UNIFORM_COLOR_CONVERSION_MATRIX] = [_program uniformIndex:@"colorConversionMatrix"];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        [_currentTouches addObject:touch];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    float distX = [touch locationInView:touch.view].x - [touch previousLocationInView:touch.view].x;
    float distY = [touch locationInView:touch.view].y - [touch previousLocationInView:touch.view].y;
    distX *= -0.005;
    distY *= -0.005;
    fingerRotationX += distY *  overture / 100;
    fingerRotationY -= distX *  overture / 100;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        [_currentTouches removeObject:touch];
    }
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        [_currentTouches removeObject:touch];
    }
}

- (void)handlePinchGesture:(UIPinchGestureRecognizer *)recognizer {
    overture /= recognizer.scale;
}

@end
