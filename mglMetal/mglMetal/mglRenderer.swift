//\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
//
//  mglRenderer.swift
//  mglMetal
//
//  Created by justin gardner on 12/28/2019.
//  Copyright © 2019 GRU. All rights reserved.
//
//\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/

//\/\/\/\/\/\/\/\/\/\/\/\/\/\/
// Include section
//\/\/\/\/\/\/\/\/\/\/\/\/\/\/
import Foundation
import MetalKit

//\/\/\/\/\/\/\/\/\/\/\/\/\/\/
// Enum of command codes
//\/\/\/\/\/\/\/\/\/\/\/\/\/\/
enum mglCommands : UInt16 {
    case ping = 0
    case clearScreen = 1
    case dots = 2
}
//\/\/\/\/\/\/\/\/\/\/\/\/\/\/
// mglRenderer: Class does most of the work
// handles initializing of the GPU, pipeline states etc
// handles the frame updates and drawing as well as resizing
//\/\/\/\/\/\/\/\/\/\/\/\/\/\/
class mglRenderer: NSObject {
    // GPU Device
    static var device : MTLDevice!
    // commandQueue which tells the device what to do
    static var commandQueue: MTLCommandQueue!
    // Mesh contains the models - i.e. vertices / triangles that will be drawn
    var mesh: MTKMesh!
    // Conversion of mesh into metal vertices
    var vertexBuffer: MTLBuffer!
    // pipeline contains the shaders and other information
    // that define the pipeline of the GPU renderer
    var pipelineState: MTLRenderPipelineState!
    
    // Pipeline state for rendering dots
    var pipelineStateDots: MTLRenderPipelineState!
    // vertex buffer for dots - will be allocated from device
    var vertexBufferDots: MTLBuffer!
    // index buffer for dots
    var indexBufferDots: MTLBuffer!
    
    // variable to hold mglCommunicator which
    // communicates with matlab
    var commandInterface : mglCommandInterface
    
    //\/\/\/\/\/\/\/\/\/\/\/\/\/\/
    // init
    //\/\/\/\/\/\/\/\/\/\/\/\/\/\/
    init(metalView: MTKView) {
        // init mglCommunicator
        commandInterface = mglCommandInterface()
        
        // Initialize the GPU device
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("GPU not available")
        }
        // tell the view aand renderer about the device
        metalView.device = device
        mglRenderer.device = device
         
        // initialize the command queue
        mglRenderer.commandQueue = device.makeCommandQueue()!
        
        // create a cube - for testing
        let mdlMesh = mglPrimitive.cube(device: device, size: 1.0)
        mesh = try! MTKMesh(mesh: mdlMesh, device: device)
        vertexBuffer = mesh.vertexBuffers[0].buffer
        
        // create a library for storing the shaders
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction = library?.makeFunction(name: "fragment_main")
        
        // create the pripeline descriptor which describes
        // the shaders and other things necessary for defining
        // the drawing state of the GPU
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        // This describes how the vertices should be interpreted by the GPU
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mdlMesh.vertexDescriptor)
        // this describes the pixel format that will be used
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        // Ok. Now tell the GPU about this to make a pipeline state
        // which can be used for rendering
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
           fatalError(error.localizedDescription)
        }
        
        // Set up a pipelineState for rendering dots
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragment_dots")
        // Setup the pipeline with the device
        do {
            pipelineStateDots = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
           fatalError(error.localizedDescription)
        }
        
        // init the super class
        super.init()
        
        // Set the clear color for the view
        metalView.clearColor = MTLClearColor(red: 0.5, green: 0.5,
                                              blue: 0.5, alpha: 1)
        // Tell the view that this class will be used as the
        // delegate - this makes it so that the view will call
        // the draw function each frame update and the resize function
        metalView.delegate = self
        
        // Done. Print out that we did something.
        print("(mglMetal:mglRenderer) Init mglRenderer")
     }
 }

//\/\/\/\/\/\/\/\/\/\/\/\/\/\/
// mtkViewDelegate: adds functionality to take care of
// resizing screen or frame updates
//\/\/\/\/\/\/\/\/\/\/\/\/\/\/
extension mglRenderer: MTKViewDelegate {
    //\/\/\/\/\/\/\/\/\/\/\/\/\/\/
    // mtkView delegate function that runs when drawable size changes
    //\/\/\/\/\/\/\/\/\/\/\/\/\/\/
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
       print("(mglMetal:mglRenderer) drawableSizeWillChange \(size)")
    }
    //\/\/\/\/\/\/\/\/\/\/\/\/\/\/
    // darw delegate which does all the work! Run every frame buffer update
    //\/\/\/\/\/\/\/\/\/\/\/\/\/\/
    func draw(in view: MTKView) {
        
        // check matlab command queue
        if commandInterface.dataWaiting() {
            let command = commandInterface.readCommand()
            switch command {
                case mglCommands.ping: print("ping")
                case mglCommands.clearScreen: clearScreen(view : view)
                case mglCommands.dots: dots(view: view)
                default: print("(mglRenderer:draw) Unknown command")
            }
        }
        
        // Get the commandBuffer and renderEncoder
        guard let descriptor = view.currentRenderPassDescriptor,
        let commandBuffer = mglRenderer.commandQueue.makeCommandBuffer(),
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        // set the renderEncoder pipeline state
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Give it our vertices
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        for submesh in mesh.submeshes {renderEncoder.drawIndexedPrimitives(type: .triangle,indexCount: submesh.indexCount,indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
        }
        // done
        renderEncoder.endEncoding()
        
        // set the drawable, present and commit - should draw after this
        guard let drawable = view.currentDrawable else {
             return
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    //\/\/\/\/\/\/\/\/\/\/\/\/\/\/
    // clearScreen
    //\/\/\/\/\/\/\/\/\/\/\/\/\/\/
    func clearScreen(view: MTKView) {
        // Set the clear color for the view
        view.clearColor = MTLClearColor(red: 0.5, green: 0.4,
                                              blue: 0.8, alpha: 1)

    }
    
    //\/\/\/\/\/\/\/\/\/\/\/\/\/\/
    // dots
    //\/\/\/\/\/\/\/\/\/\/\/\/\/\/
    func dots(view: MTKView) {
        // Set the clear color for the view
        view.clearColor = MTLClearColor(red: 0.5, green: 0.4,
                                              blue: 0.8, alpha: 1)
        // get vertices
        let vertexCount = 3
        let indexCount = 1
        // get an MTLBuffer for holding the vertices
        vertexBufferDots = mglRenderer.device.makeBuffer(length: vertexCount * 3 * MemoryLayout<Float>.stride)
        // read the vertex data from the command interface
        commandInterface.readData(count: vertexCount * 3 * MemoryLayout<Float>.stride, buf: vertexBufferDots.contents())
        // print vertices out (for debugging)
        do {
            let rawPointer = vertexBufferDots.contents()
            let typedPointer = rawPointer.bindMemory(to: Float.self, capacity: vertexCount * 3)
            let bufferPointer = UnsafeBufferPointer<Float>(start: typedPointer, count: vertexCount * 3)
            for (index, value) in bufferPointer.enumerated() {
                print("Vertex value: \(index): \(value)")
            }
        }
        // get an MTLBuffer for holding the indexes
        indexBufferDots = mglRenderer.device.makeBuffer(length: indexCount*3)
        // read the index data from the command interface
        commandInterface.readData(count: indexCount * 3 * MemoryLayout<UInt16>.stride, buf: indexBufferDots.contents())
        do {
            // print indexes out (for debugging)
            let rawPointer = indexBufferDots.contents()
            let typedPointer = rawPointer.bindMemory(to: UInt16.self, capacity: indexCount * 3)
            let bufferPointer = UnsafeBufferPointer<UInt16>(start: typedPointer, count: indexCount * 3)
            for (index, value) in bufferPointer.enumerated() {
                print("Index value: \(index): \(value)")
            }
        }
    }
}
