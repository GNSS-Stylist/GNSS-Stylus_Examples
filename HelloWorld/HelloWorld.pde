/*
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <http://unlicense.org/>
*/

/* 
Written by Pasi Nuutinmaki (gnssstylist <at> sci <dot> fi), 2019
Processing version used: 3.5.3

This is a program to animate/view the results generated 
using GNSS-stylus. This is somewhat beautified version
of the original used to generate the video
(https://www.youtube.com/watch?v=3b9ipsEoL9s).
Texture used in the video is replaced with generic 
xor-texture here.
*/

// File name of the file to load the "movie script" from
final String movieScriptFileName = "HelloWorld.MovieScript";

// Class to store the information of a single object in the scene
class DrawObject
{
  String fileName;    // Filename of the (.obj)-file to load
  int fillColor;      // Color of the object to be drawn (includes alpha)
  
  DrawObject(String fileName, int fillColor)
  {
    this.fileName = fileName;
    this.fillColor = fillColor;
  }
}

// "Default" alpha of the drawn object (used in the "Scene"-definition below)
final int objectAlpha = 128;

// "Default" directory of the .obj-files (used in the "Scene"-definition below)
final String objDir = "";

// Scene-related settings (values rudely defined as defaults here, sorry...)
class Scene
{
  float groundLevel = 0.3;      // Level (translation) of the ground plane (Y - coord)
  float groundPlaneXTrans = 0;     // Translation of the ground plane X coordinate
  float groundPlaneZTrans = 0;     // Translation of the ground plane Z coordinate
  float groundPlaneRotation = 0;   // Rotation of the ground plane (radians)
  boolean drawGroundPlane = true;  // Draw the ground plane?
  String groundTextureFileName = "XorTexture_256_256.png";  // Where to load the texture from?
  float groundPlaneSize = 2000;    // Size of the ground plane in world coordinates (most likely meters)
  int textureScaling = 256000;      // Scaling of the ground texture (how many texture "tiles" to fit into ground plane) 
  
  DrawObject[] drawObjects =
  {
    // Objects to be drawn are defined here with colors and alpha.
    // (No objects in hello world)
  };
}

// Camera-related settings (values rudely defined as defaults here, sorry...)
class Camera
{
    // Camera types as "static final ints" as Processing doesn't support enum(?)
  public static final int CAMERATYPE_ROTATING = 1;
  public static final int CAMERATYPE_STICK = 2;
  
  public int cameraType = CAMERATYPE_ROTATING;  // CAMERATYPE_XXX above

  // Rotating camera parameters used only when camera type is CAMERATYPE_ROTATING
  float rotatingCameraLookAtX = -1.15;    // Point where rotating camera looks at and rotates around 
  float rotatingCameraLookAtY = -0.5;        // Point where rotating camera looks at and rotates around
  float rotatingCameraLookAtZ = 0;     // Point where rotating camera looks at and rotates around

  float rotatingCameraHeight = 1.5;         // Height of the rotating camera
  float rotatingCameraDistance = 4;      // Distance of the camera from the point defined by rotatingCameraLookAtX&Y&Z
  
  float rotatingCameraSpeed = 36;         // Degrees / sec
}

// Instantiate the classes. No need to set values for the fields because default values are used.
// This is rude. Maybe there is some nicer way to do this in Processing?
final Scene scene = new Scene();
final Camera camera = new Camera();
final int fps = 30;

// Multipliers for the accuracy boxes. Value 1 draws the accuracy box sized as given in the script 
final float accBoxSizeMultiplier_Cloud = 1;  // Dimensions of the boxes drawn around the point cloud points are multiplied by this
final float accBoxSizeMultiplier_Tip = 1;  // Dimensions of the box drawn around the stylus tip is multiplied by this
final float accBoxSizeMultiplier_Rovers = 1;  // Dimensions of the boxes drawn around the rover coordinates are multiplied by this

// Set if you want to output video frames as separate files (SLOW AND USES HUGE AMOUNTS OF DISK SPACE!)
boolean outputVideoFrames = false;
// This will be appended with the frame index
String videoFrameFileNamePrefix = "VideoFrames/Frame_";

// Class for a single script item (represents one frame)
class ScriptItem
{
  public int iTOW;      // iTOW (integer Time Of Week (milliseconds since the beginning of GPS-week))
  boolean interpolated; // Is this frame interpolated (GNSS-Stylus SW creates frames with (piecewise linearly) interpolated values if no matching iTOW is found) 
  
  public float tipX, tipY, tipZ;                     // Coordinates of the stylus tip
  public float tipXAcc, tipYAcc, tipZAcc;            // Accuracies of the stylus tip coordinates
  public float roverAX, roverAY, roverAZ;            // Coordinates of the rover A antenna
  public float roverAXAcc, roverAYAcc, roverAZAcc;   // Accuracies of the rover A antenna coordinates
  public float roverBX, roverBY, roverBZ;            // Coordinates of the rover B antenna
  public float roverBXAcc, roverBYAcc, roverBZAcc;   // Accuracies of the rover A antenna coordinates

  public float cameraPosX,cameraPosY,cameraPosZ;     // Stick-attached camera position
  public float lookX, lookY, lookZ;                  // "Look at" coordinates for the camera
};

// Class for a single point cloud item 
class PointCloudItem
{
  // Item types as "static final ints" as Processing doesn't support enum(?)
  public static final int PCITYPE_STARTLINE = 1;
  public static final int PCITYPE_CONTINUELINE = 2;
  public static final int PCITYPE_ENDLINE = 3;
  
  public int iTOW;      // iTOW (integer Time Of Week (milliseconds since the beginning of GPS-week))
  
  public int itemType;  // PCITYPE_XXX above
  
  public float tipX, tipY, tipZ;           // Coordinates of the point 
  public float tipXAcc, tipYAcc, tipZAcc;  // Accuracy of the coordinates
  String objectName;                       // Object name this point is part of
};

ScriptItem[] script; // Storage for the script
int numOfFramesInScript = 0;

PointCloudItem[] cloud; // Storage for the point cloud
int numOfPointsInCloud = 0;

PShape[] shapes; // Storage for shapes (objects loaded from .obj-files)           

PImage groundTexture;
PShape groundPlane;

int scriptIndex = 0;

void setup() {
  size(960, 540, P3D);
  background(0);
  
  stroke(255);
  strokeWeight(1);
  
  // Load .obj-files into shapes
  shapes = new PShape[scene.drawObjects.length];
  int shapeIndex = 0;
  for (DrawObject obj : scene.drawObjects) {
    shapes[shapeIndex] = loadShape(obj.fileName);
    shapes[shapeIndex].setFill(obj.fillColor);
    shapeIndex++;
  }

  frameRate(fps);
  
  float fov = 0.62;
  
  perspective(fov, float(width)/float(height), 0.1, 100);
  
  String[] scriptLines = loadStrings(movieScriptFileName);
  
  // Count items in the movie script  
  for (int i = 0 ; i < scriptLines.length; i++) 
  {
    String[] subItems = split(scriptLines[i], "\t");
    
    if ((subItems[0].toLowerCase().equals("lstart")) || 
      (subItems[0].toLowerCase().equals("lcont")) ||
      (subItems[0].toLowerCase().equals("lend")))
    {
      numOfPointsInCloud++;
    }
    else if ((subItems[0].toLowerCase().equals("f_key")) ||
      (subItems[0].toLowerCase().equals("f_interp")))
    {
      numOfFramesInScript++;
    }
  }
  
  // Reserve space
  script = new ScriptItem[numOfFramesInScript];
  cloud = new PointCloudItem[numOfPointsInCloud];
  
  int cloudIndex = 0;
  int scriptIndex = 0;
  
  // Interpret the movie script
  for (int i = 0 ; i < scriptLines.length; i++) 
  {
    // All items are simple lines of tab-separated strings
    String[] subItems = split(scriptLines[i], "\t");
    
    if (subItems[0].toLowerCase().equals("lstart"))
    {
      // This line defines a start of a "line set"
      // (user pressed mouse button used to add a tag indicating beginning of object points)
      cloud[cloudIndex] = new PointCloudItem();
      cloud[cloudIndex].iTOW = Integer.parseInt(subItems[1]);
      cloud[cloudIndex].itemType = PointCloudItem.PCITYPE_STARTLINE;
      
      cloud[cloudIndex].tipX = float(subItems[2]);
      cloud[cloudIndex].tipY = float(subItems[3]);
      cloud[cloudIndex].tipZ = float(subItems[4]);
      
      cloud[cloudIndex].tipXAcc = float(subItems[5]);
      cloud[cloudIndex].tipYAcc = float(subItems[6]);
      cloud[cloudIndex].tipZAcc = float(subItems[7]);
      
      cloud[cloudIndex].objectName = new String(subItems[8]);

      cloudIndex++;
    }
    else if (subItems[0].toLowerCase().equals("lcont"))
    {
      // This line defines next point of the "line set"
      cloud[cloudIndex] = new PointCloudItem();
      cloud[cloudIndex].iTOW = Integer.parseInt(subItems[1]);
      cloud[cloudIndex].itemType = PointCloudItem.PCITYPE_CONTINUELINE;
      
      cloud[cloudIndex].tipX = float(subItems[2]);
      cloud[cloudIndex].tipY = float(subItems[3]);
      cloud[cloudIndex].tipZ = float(subItems[4]);
      
      cloud[cloudIndex].tipXAcc = float(subItems[5]);
      cloud[cloudIndex].tipYAcc = float(subItems[6]);
      cloud[cloudIndex].tipZAcc = float(subItems[7]);

      cloud[cloudIndex].objectName = new String(subItems[8]);

      cloudIndex++;
    }
    else if (subItems[0].toLowerCase().equals("lend"))
    {
      // This line defines the end of the "line set"
      cloud[cloudIndex] = new PointCloudItem();
      cloud[cloudIndex].iTOW = Integer.parseInt(subItems[1]);
      cloud[cloudIndex].itemType = PointCloudItem.PCITYPE_ENDLINE;
      
      cloud[cloudIndex].tipX = float(subItems[2]);
      cloud[cloudIndex].tipY = float(subItems[3]);
      cloud[cloudIndex].tipZ = float(subItems[4]);
      
      cloud[cloudIndex].tipXAcc = float(subItems[5]);
      cloud[cloudIndex].tipYAcc = float(subItems[6]);
      cloud[cloudIndex].tipZAcc = float(subItems[7]);

      cloud[cloudIndex].objectName = new String(subItems[8]);

      cloudIndex++;
    }
    else if ((subItems[0].toLowerCase().equals("f_key")) ||
      (subItems[0].toLowerCase().equals("f_interp")))
    {
      // This line defines the setting for a single video frame
      script[scriptIndex] = new ScriptItem();
      
      script[scriptIndex].iTOW = Integer.parseInt(subItems[1]);
      script[scriptIndex].interpolated = subItems[0].toLowerCase().equals("f_interp");
      script[scriptIndex].tipX = float(subItems[2]);
      script[scriptIndex].tipY = float(subItems[3]);
      script[scriptIndex].tipZ = float(subItems[4]);
      script[scriptIndex].roverAX = float(subItems[5]);
      script[scriptIndex].roverAY = float(subItems[6]);
      script[scriptIndex].roverAZ = float(subItems[7]);
      script[scriptIndex].roverBX = float(subItems[8]);
      script[scriptIndex].roverBY = float(subItems[9]);
      script[scriptIndex].roverBZ = float(subItems[10]);
      script[scriptIndex].tipXAcc = float(subItems[11]);
      script[scriptIndex].tipYAcc = float(subItems[12]);
      script[scriptIndex].tipZAcc = float(subItems[13]);
      script[scriptIndex].roverAXAcc = float(subItems[14]);
      script[scriptIndex].roverAYAcc = float(subItems[15]);
      script[scriptIndex].roverAZAcc = float(subItems[16]);
      script[scriptIndex].roverBXAcc = float(subItems[17]);
      script[scriptIndex].roverBYAcc = float(subItems[18]);
      script[scriptIndex].roverBZAcc = float(subItems[19]);

      script[scriptIndex].cameraPosX = float(subItems[20]);
      script[scriptIndex].cameraPosY = float(subItems[21]);
      script[scriptIndex].cameraPosZ = float(subItems[22]);

      script[scriptIndex].lookX = float(subItems[23]);
      script[scriptIndex].lookY = float(subItems[24]);
      script[scriptIndex].lookZ = float(subItems[25]);

      scriptIndex++;
    }

  }
  
  groundTexture = loadImage(scene.groundTextureFileName);  
  
  groundPlane = createShape();
  groundPlane.beginShape();
  textureWrap(REPEAT);
  groundPlane.strokeWeight(0);
  groundPlane.texture(groundTexture);
  groundPlane.vertex(-scene.groundPlaneSize / 2, 0, -scene.groundPlaneSize / 2, 0,   0);
  groundPlane.vertex(scene.groundPlaneSize / 2, 0, -scene.groundPlaneSize / 2, scene.textureScaling, 0);
  groundPlane.vertex(scene.groundPlaneSize / 2, 0, scene.groundPlaneSize / 2, scene.textureScaling, scene.textureScaling);
  groundPlane.vertex(-scene.groundPlaneSize / 2, 0,scene.groundPlaneSize / 2, 0, scene.textureScaling);
  groundPlane.endShape(CLOSE);
} //<>//

void draw() 
{
  ambientLight(128, 128, 128);
 
  switch (camera.cameraType)
  {
  case Camera.CAMERATYPE_ROTATING:

    // Calculate rotation in radians based on the current frame counter and settings
    float cameraRotationXZ = frameCount * camera.rotatingCameraSpeed / fps * 2 * PI / 360;

    // Directional light to the looking direction
    directionalLight(128, 128, 128, -(sin(cameraRotationXZ) * camera.rotatingCameraDistance + camera.rotatingCameraLookAtX),
      - camera.rotatingCameraHeight,
      -(cos(cameraRotationXZ) * camera.rotatingCameraDistance + camera.rotatingCameraLookAtZ));
    
    // Set camera location to rotate around the "look at"-point.
    camera(sin(cameraRotationXZ) * camera.rotatingCameraDistance + camera.rotatingCameraLookAtX,
      - camera.rotatingCameraHeight,
      cos(cameraRotationXZ) * camera.rotatingCameraDistance + camera.rotatingCameraLookAtZ,
      camera.rotatingCameraLookAtX, camera.rotatingCameraLookAtY, camera.rotatingCameraLookAtZ,
      0, 1, 0);
      
    break;
      
  case Camera.CAMERATYPE_STICK:
  default:
    
    // Set point light to camera position (read from the "movie script")
    pointLight(128, 128, 128,
    script[scriptIndex].cameraPosX,
      script[scriptIndex].cameraPosY,
      script[scriptIndex].cameraPosZ);
    
    // Camera position is read from the "movie script"
    camera(script[scriptIndex].cameraPosX,
      script[scriptIndex].cameraPosY,
      script[scriptIndex].cameraPosZ,
      script[scriptIndex].lookX,
      script[scriptIndex].lookY,
      script[scriptIndex].lookZ,
      0, 1, 0);
      
    break;
  }
  
  background(0);

  strokeWeight(0);

  if (scene.drawGroundPlane)
  {
    // Draw ground plane to the defined coordinates
    pushMatrix();
    translate(scene.groundPlaneXTrans, scene.groundLevel, scene.groundPlaneZTrans);
    rotateY(scene.groundPlaneRotation);
    shape(groundPlane);
    popMatrix();
  }
 
  fill(255,255,255);
  
  int minITOW = script[0].iTOW;
  int maxITOW = script[scriptIndex].iTOW;
  
  boolean lastPointKnown = false;
  float lastX = 0, lastY = 0, lastZ = 0;
  
  strokeWeight(5);

  for (int i = 0; i < numOfPointsInCloud; i++)
  {
    // Draw lines between the points in the cloud that are in the iTOW range as defined in the script
    // (minimum iTOW comes from the starting value of the script and maximum represents
    // the currently drawn frame).
    if ((cloud[i].iTOW >= minITOW) && (cloud[i].iTOW <= maxITOW))
    {
      if (cloud[i].itemType == PointCloudItem.PCITYPE_STARTLINE)
      {
        lastX = cloud[i].tipX;
        lastY = cloud[i].tipY;
        lastZ = cloud[i].tipZ;
         
        lastPointKnown = true;
      }
      else if (cloud[i].itemType == PointCloudItem.PCITYPE_CONTINUELINE)
      {
        if (lastPointKnown)
        {
          line(lastX, lastY, lastZ, cloud[i].tipX, cloud[i].tipY, cloud[i].tipZ);
        }
         
        lastX = cloud[i].tipX;
        lastY = cloud[i].tipY;
        lastZ = cloud[i].tipZ;
      }
      else if (cloud[i].itemType == PointCloudItem.PCITYPE_ENDLINE)
      {
        lastPointKnown = false;
      }
    }
  }
  
  strokeWeight(0);
  
  for (int i = 0; i < numOfPointsInCloud; i++)
  {
    // Draw boxed around all the points in the cloud that are in the iTOW range as defined in the script
    // (minimum iTOW comes from the starting value of the script and maximum represents
    // the currently drawn frame).
    if ((cloud[i].iTOW >= minITOW) && (cloud[i].iTOW <= maxITOW))
    {
      float accBoxXSize = cloud[i].tipXAcc * accBoxSizeMultiplier_Cloud;
      float accBoxYSize = cloud[i].tipYAcc * accBoxSizeMultiplier_Cloud;
      float accBoxZSize = cloud[i].tipZAcc * accBoxSizeMultiplier_Cloud;
       
      pushMatrix();
      translate(cloud[i].tipX, 
        cloud[i].tipY,
        cloud[i].tipZ);
      
      box(accBoxXSize, accBoxYSize, accBoxZSize);
      popMatrix();
    }
  }
  
  strokeWeight(0);

  for (PShape shape : shapes) {
    shape(shape, 0, 0);
  }

  strokeWeight(4);
  
  // Draw the stylus stick
  line(script[scriptIndex].roverBX, script[scriptIndex].roverBY, script[scriptIndex].roverBZ, script[scriptIndex].roverAX, script[scriptIndex].roverAY, script[scriptIndex].roverAZ);
  line(script[scriptIndex].roverAX, script[scriptIndex].roverAY, script[scriptIndex].roverAZ, script[scriptIndex].tipX, script[scriptIndex].tipY, script[scriptIndex].tipZ);
  
  strokeWeight(1);

  // Draw a box around the stylus tip scaled as defined
  float accBoxXSize = script[scriptIndex].tipXAcc * accBoxSizeMultiplier_Tip;
  float accBoxYSize = script[scriptIndex].tipYAcc * accBoxSizeMultiplier_Tip;
  float accBoxZSize = script[scriptIndex].tipZAcc * accBoxSizeMultiplier_Tip;
  pushMatrix();
  translate(script[scriptIndex].tipX, 
    script[scriptIndex].tipY,
    script[scriptIndex].tipZ);
  
  box(accBoxXSize, accBoxYSize, accBoxZSize);
  popMatrix();

  // Draw a box around the rover a scaled as defined
  accBoxXSize = script[scriptIndex].roverAXAcc * accBoxSizeMultiplier_Rovers;
  accBoxYSize = script[scriptIndex].roverAYAcc * accBoxSizeMultiplier_Rovers;
  accBoxZSize = script[scriptIndex].roverAZAcc * accBoxSizeMultiplier_Rovers;
  pushMatrix();
  translate(script[scriptIndex].roverAX, 
    script[scriptIndex].roverAY,
    script[scriptIndex].roverAZ);
  
  box(accBoxXSize, accBoxYSize, accBoxZSize);
  popMatrix();

  // Draw a box around the rover b scaled as defined
  accBoxXSize = script[scriptIndex].roverBXAcc * accBoxSizeMultiplier_Rovers;
  accBoxYSize = script[scriptIndex].roverBYAcc * accBoxSizeMultiplier_Rovers;
  accBoxZSize = script[scriptIndex].roverBZAcc * accBoxSizeMultiplier_Rovers;
  pushMatrix();
  translate(script[scriptIndex].roverBX, 
    script[scriptIndex].roverBY,
    script[scriptIndex].roverBZ);
  
  box(accBoxXSize, accBoxYSize, accBoxZSize);
  popMatrix();

  if (outputVideoFrames)
  {
    // Output video frames if defined.
    // THIS USES HUGE AMOUNT OF DISK SPACE AND SLOWES THE PROGRAM DOWN!
    String fileIndex = nf(scriptIndex + 1, 5);
    String fileName = videoFrameFileNamePrefix + fileIndex + ".tif";
    
    save(fileName);
  }

  scriptIndex++;

  if (scriptIndex >= numOfFramesInScript)
  {
    // Stop outputting video frames after the first round
    outputVideoFrames = false;
    scriptIndex = 0;
  }
}
