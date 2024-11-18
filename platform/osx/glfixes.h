#include <OpenGL/gl.h>
#include <OpenGL/glext.h>

#define glGenVertexArrays 			glGenVertexArraysAPPLE
#define glBindVertexArray 			glBindVertexArrayAPPLE
#define glDeleteVertexArrays 		glDeleteVertexArraysAPPLE
#define glIsVertexArray 			glIsVertexArrayAPPLE

#define glGenFramebuffers 			glGenFramebuffersEXT
#define glBindFramebuffer 			glBindFramebufferEXT
#define glBlitFramebuffer 			glBlitFramebufferEXT
#define glFramebufferTexture2D 		glFramebufferTexture2DEXT
#define glDeleteFramebuffers		glDeleteFramebuffersEXT
#define glCheckFramebufferStatus 	glCheckFramebufferStatusEXT

#define GL_MAX_SAMPLES				GL_MAX_SAMPLES_EXT

#define GL_FRAMEBUFFER 				GL_FRAMEBUFFER_EXT
#define GL_READ_FRAMEBUFFER			GL_READ_FRAMEBUFFER_EXT
#define GL_DRAW_FRAMEBUFFER			GL_DRAW_FRAMEBUFFER_EXT
#define GL_FRAMEBUFFER_COMPLETE 	GL_FRAMEBUFFER_COMPLETE_EXT


#define GL_PIXEL_PACK_BUFFER		GL_PIXEL_PACK_BUFFER_ARB

#define glGenerateMipmap 			glGenerateMipmapEXT

#define glBindRenderbuffer 			glBindRenderbufferEXT
#define glGenRenderbuffers 			glGenRenderbuffersEXT
#define glDeleteRenderbuffers 		glDeleteRenderbuffersEXT
#define glIsRenderbuffer 			glIsRenderbufferEXT
#define glRenderbufferStorage 		glRenderbufferStorageEXT
#define glFramebufferRenderbuffer	glFramebufferRenderbufferEXT

#define glBindBufferBase			glBindBufferBaseEXT
#define glBeginTransformFeedback	glBeginTransformFeedbackEXT
#define glEndTransformFeedback	glEndTransformFeedbackEXT

#define glRenderbufferStorageMultisample	glRenderbufferStorageMultisampleEXT
#define GL_INVALID_FRAMEBUFFER_OPERATION GL_INVALID_FRAMEBUFFER_OPERATION_EXT

#define GL_RENDERBUFFER				GL_RENDERBUFFER_EXT

#define GL_RGBA32F					GL_RGBA32F_ARB
#define GL_RGB32F					GL_RGB32F_ARB
#define GL_HALF_FLOAT				GL_HALF_FLOAT_ARB

#define GL_DEPTH_ATTACHMENT			GL_DEPTH_ATTACHMENT_EXT
#define GL_COLOR_ATTACHMENT0 		GL_COLOR_ATTACHMENT0_EXT
#define GL_COLOR_ATTACHMENT1 		GL_COLOR_ATTACHMENT1_EXT
#define GL_COLOR_ATTACHMENT2 		GL_COLOR_ATTACHMENT2_EXT
#define GL_COLOR_ATTACHMENT3 		GL_COLOR_ATTACHMENT3_EXT

#define glClearDepthf glClearDepth
#define glDepthRangef glDepthRange
