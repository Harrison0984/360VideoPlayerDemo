//
//  OpenGLProgram.h
//  360PlayerDemo
//
//  Created by heyunpeng on 16/5/8.
//  Copyright © 2016年 heyunpeng. All rights reserved.
//

#ifndef OpenGLProgram_h
#define OpenGLProgram_h

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@interface OpenGLProgram : NSObject

@property (nonatomic, strong) NSMutableArray *attributes;
@property (nonatomic, strong) NSMutableArray *uniforms;
@property (nonatomic, assign) GLuint vertShader;
@property (nonatomic, assign) GLuint fragShader;
@property (nonatomic, assign) GLuint program;

- (id)initWithVertexFilepath:(NSString *)shaderFilename fragmentShaderFilename:(NSString *)fShaderFilename;

- (void)addAttribute:(NSString *)attributeName;
- (GLuint)attributeIndex:(NSString *)attributeName;
- (GLuint)uniformIndex:(NSString *)uniformName;

- (BOOL)link;
- (void)use;

@end

#endif /* OpenGLProgram_h */
