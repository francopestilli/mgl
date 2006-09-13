#ifdef documentation
=========================================================================

     program: mglGetKeys.c
          by: justin gardner
        date: 09/12/06
     purpose: return state of keyboard

$Id$
=========================================================================
#endif



/////////////////////////
//   include section   //
/////////////////////////
#include "mgl.h"

/////////////
//   main   //
//////////////
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  int longNum;int bitNum;int logicalNum = 0;
  int returnAllKeys = 1,i,n,displayKey;
  double *inptr,*outptr;
  // get which key we want
  if (nrhs == 1) {
    inptr = mxGetPr(prhs[0]);
    if (inptr != NULL)
      returnAllKeys = 0;
  }
  else if (nrhs != 0) {
    usageError("mglGetKeys");
    return;
  }

#ifdef __APPLE__
  //  get the status of the keyboard
  KeyMap theKeys;
  GetKeys(theKeys);

  if (!returnAllKeys) {
    // figure out how many elements are desired
    n = mxGetN(prhs[0]);
    // and create an output matrix
    plhs[0] = mxCreateDoubleMatrix(1,n,mxREAL);
    outptr = mxGetPr(plhs[0]);
    // now go through and get each key
    for (i=0; i<n; i++) {
      displayKey = (int)*(inptr+i);
      if ((displayKey < 0) || (displayKey > 128)) {
	mexPrintf("(mglGetKeys) Key %i out of range 1:128",displayKey);
	return;
      }
      div_t keypos = div(displayKey-1,32);
      *(outptr+i) = (theKeys[keypos.quot] >> keypos.rem) & 0x1;
    }
  }
  else {
    // return it in a logical array
    plhs[0] = mxCreateLogicalMatrix(1,128);
    mxLogical *outptr = mxGetLogicals(plhs[0]);
   
    // set the elements of the logical array correctly
    for (longNum = 0;longNum<4;longNum++) {
      for (bitNum = 0;bitNum<32;bitNum++) {
	*(outptr+logicalNum++) = (theKeys[longNum] >> bitNum) & 0x1;
      }
    }
  }

  // and display the same if verbose is set
  int verbose = mglGetGlobalDouble("verbose");
  if (verbose) {
    mexPrintf("(mglGetKeys) Keystate = ");
    for (longNum=0;longNum<4;longNum++) {
      for (bitNum = 0;bitNum<32;bitNum++) {
	mexPrintf("%i ",(theKeys[longNum] >> bitNum) & 0x1);
      }
    }
    mexPrintf("\n");
  }
#endif
#ifdef __linux__
  mexPrintf("(mglGetKeys) Not supported yet on linux\n");
  return;
#endif 
}
