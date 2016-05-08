//
//  OpenGLProgram.m
//  360PlayerDemo
//
//  Created by heyunpeng on 16/5/8.
//  Copyright © 2016年 heyunpeng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OpenGLProgram.h"

@implementation OpenGLProgram

- (id)initWithVertexFilepath:(NSString *)shaderFilename fragmentShaderFilename:(NSString *)fShaderFilename {
    self = [super init];
    
    NSString *vertShaderPathname = [[NSBundle mainBundle] pathForResource:shaderFilename ofType:@"vsh"];
    NSString *vertexShaderString = [NSString stringWithContentsOfFile:vertShaderPathname encoding:NSUTF8StringEncoding error:nil];
    
    NSString *fragShaderPathname = [[NSBundle mainBundle] pathForResource:fShaderFilename ofType:@"fsh"];
    NSString *fragmentShaderString = [NSString stringWithContentsOfFile:fragShaderPathname encoding:NSUTF8StringEncoding error:nil];
    
    if (self) {
        _attributes = [[NSMutableArray alloc] init];
        _uniforms = [[NSMutableArray alloc] init];
        _program = glCreateProgram();
        
        [self compileShader:&_vertShader type:GL_VERTEX_SHADER string:vertexShaderString];
        [self compileShader:&_fragShader type:GL_FRAGMENT_SHADER string:fragmentShaderString];
        
        glAttachShader(_program, _vertShader);
        glAttachShader(_program, _fragShader);
    }
    
    return self;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type string:(NSString *)shaderString {
    const GLchar *source = (GLchar *)[shaderString UTF8String];
    if (!source) {
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
    GLint status;
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    
    return status == GL_TRUE;
}

- (void)addAttribute:(NSString *)attributeName {
    if (![self.attributes containsObject:attributeName]) {
        [self.attributes addObject:attributeName];
        glBindAttribLocation(self.program, (GLuint)[self.attributes indexOfObject:attributeName], [attributeName UTF8String]);
    }
}

- (GLuint)attributeIndex:(NSString *)attributeName {
    return (GLuint)[self.attributes indexOfObject:attributeName];
}

- (GLuint)uniformIndex:(NSString *)uniformName {
    return glGetUniformLocation(self.program, [uniformName UTF8String]);
}

- (BOOL)link {
    glLinkProgram(self.program);
    
    GLint status;
    glGetProgramiv(self.program, GL_LINK_STATUS, &status);
    
    if (self.vertShader) {
        glDeleteShader(self.vertShader);
        self.vertShader = 0;
    }
    if (self.fragShader) {
        glDeleteShader(self.fragShader);
        self.fragShader = 0;
    }
    
    return YES;
}

- (void)use {
    glUseProgram(self.program);
}

- (void)dealloc {
    if (_vertShader)
        glDeleteShader(_vertShader);
    
    if (_fragShader)
        glDeleteShader(_fragShader);
    
    if (_program)
        glDeleteProgram(_program);
}

@end