#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 res;
uniform vec2 imgRes;
uniform float imgFade;
uniform vec2 plusCenter;
uniform float plusRadius;
uniform vec2 capCenter;
uniform vec2 capHalf;
uniform float capRadius;
uniform vec2 btnCenter;
uniform float btnRadius;
uniform float plusPress;
uniform float plusPulse;
uniform float capPress;
uniform float btnPress;
uniform float isFocused;
uniform float sendPulse;
uniform vec2 headerCenter;
uniform vec2 headerHalf;
uniform vec2 actionCenter;
uniform vec2 actionHalf;
uniform vec2 videoCenter;
uniform vec2 callCenter;
uniform float headerBtnR;
uniform float videoPress;
uniform float callPress;
uniform vec3 uEnvColor;
uniform sampler2D uBgTex;

out vec4 fragColor;

float sdRoundBox(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - (b - r);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a, ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h);
}

float samplePlusIcon(vec2 p, float scale) {
  float s = 7.4 * scale;
  float dHoriz = sdSegment(p, vec2(-s, 0.0), vec2(s, 0.0));
  float dVert = sdSegment(p, vec2(0.0, -s), vec2(0.0, s));
  float dPlus = min(dHoriz, dVert);
  float strokeRadius = 1.35 * scale;
  return smoothstep(strokeRadius + 0.85, strokeRadius - 0.45, dPlus);
}

float sampleArrowUpIcon(vec2 p, float scale) {
  float s = 7.6 * scale;
  float dShaft = sdSegment(p, vec2(0.0, s), vec2(0.0, -s));
  float dLeft = sdSegment(p, vec2(-s * 0.78, -s * 0.15), vec2(0.0, -s));
  float dRight = sdSegment(p, vec2(s * 0.78, -s * 0.15), vec2(0.0, -s));
  float dArrow = min(dShaft, min(dLeft, dRight));
  float strokeRadius = 1.35 * scale;
  return smoothstep(strokeRadius + 0.85, strokeRadius - 0.45, dArrow);
}

vec3 sampleScene(vec2 px) {
  vec3 baseCol = vec3(0.93, 0.945, 0.965);
  if (imgFade <= 0.001) return baseCol;

  vec2 uv = px / res;
  float screenAspect = res.x / max(res.y, 1.0);
  float imgAspect = imgRes.x / max(imgRes.y, 1.0);
  vec2 coverUv = uv;

  if (screenAspect > imgAspect) {
    float s = imgAspect / screenAspect;
    coverUv.y = coverUv.y * s + (1.0 - s) * 0.5;
  } else {
    float s = screenAspect / imgAspect;
    coverUv.x = coverUv.x * s + (1.0 - s) * 0.5;
  }

  vec3 photo = texture(uBgTex, clamp(coverUv, 0.001, 0.999)).rgb;
  return mix(baseCol, photo, imgFade);
}

vec3 render3DMatteSurface(
  vec3 bgCol,
  vec3 envBounce,
  vec2 pLocal,
  float d,
  float dPenumbra,
  float dCrevice,
  float press,
  float activeGlow,
  bool isCapsule,
  bool isAccent,
  int tier
) {
  float lift = 1.0 - press * 0.60;
  bool isCircleBtn = (!isCapsule && tier == 1);
  float shadowStr = 1.20;

  float sigma = isCircleBtn ? (4.0 * lift) : ((tier == 1) ? (7.5 * lift) : (14.0 * lift));
  float distPos = max(dPenumbra, 0.0);
  float gaussPenumbra = exp(-(distPos * distPos) / (2.0 * sigma * sigma));
  float basePen = isCircleBtn ? 0.22 : ((tier == 1) ? 0.16 : 0.22);
  float penumbraStrength = basePen * lift * shadowStr;

  float creviceWidth = isCircleBtn ? 2.8 : ((tier == 1) ? 2.8 : 3.8);
  float creviceAO = smoothstep(creviceWidth, -0.5, dCrevice);
  float baseCrev = isCircleBtn ? (0.34 - press * 0.08) : ((tier == 1) ? (0.18 - press * 0.04) : (0.22 - press * 0.06));
  creviceAO = creviceAO * creviceAO * baseCrev * shadowStr;

  vec3 shadowFilter = mix(vec3(1.0), vec3(0.36, 0.42, 0.54), clamp(gaussPenumbra * penumbraStrength + creviceAO, 0.0, 0.58));
  bgCol *= shadowFilter;

  float mask = smoothstep(1.15, -0.65, d);
  if (mask <= 0.001) return bgCol;

  vec2 grad2D = normalize(pLocal + 0.0001);
  float maxThick = capRadius;
  if (isCapsule) {
    vec2 innerBox = max(vec2(0.0), capHalf - capRadius);
    vec2 spinePt = clamp(pLocal, -innerBox, innerBox);
    vec2 delta = pLocal - spinePt;
    if (length(delta) > 0.001) {
      grad2D = normalize(delta);
    } else {
      grad2D = vec2(0.0, pLocal.y / max(capHalf.y, 1.0));
    }
  } else {
    maxThick = (tier == 1) ? plusRadius : 14.0;
  }

  float depthNorm = clamp(-d / max(maxThick, 1.0), 0.0, 1.0);
  float bevelCurve = pow(1.0 - depthNorm, 1.35);
  float domeSlope = clamp(bevelCurve * (0.78 - press * 0.16) * 1.45, 0.0, 0.95);

  vec3 N = normalize(vec3(grad2D * domeSlope, sqrt(max(0.06, 1.0 - domeSlope * domeSlope))));
  vec3 L = normalize(vec3(-0.24, -0.82, 0.52));
  float wrappedDiffuse = clamp((dot(N, L) + 0.45) / 1.45, 0.0, 1.0);
  float skyFactor = 0.5 + 0.5 * (-N.y);
  float lightTerm = clamp(mix(0.76, 1.0, wrappedDiffuse * 0.72 + skyFactor * 0.28), 0.0, 1.0);

  vec3 surface;
  if (isAccent) {
    vec3 topBlue = vec3(0.18, 0.53, 0.99);
    vec3 deepBlue = vec3(0.08, 0.36, 0.85);
    surface = mix(deepBlue, topBlue, lightTerm);
    surface += envBounce * 0.04;
  } else {
    vec3 baseTop = (tier == 1) ? vec3(0.995, 0.997, 1.0) : vec3(0.975, 0.980, 0.990);
    vec3 baseBot = (tier == 1) ? vec3(0.865, 0.888, 0.930) : vec3(0.840, 0.868, 0.915);
    baseBot = mix(baseTop, baseBot, 1.25);
    if (activeGlow > 0.01) {
      baseTop = mix(baseTop, vec3(1.0), activeGlow * 0.5);
      baseBot = mix(baseBot, vec3(0.915, 0.932, 0.965), activeGlow * 0.45);
    }
    surface = mix(baseBot, baseTop, lightTerm);
    float bounceMask = (1.0 - skyFactor) * 0.045;
    surface = mix(surface, envBounce, bounceMask);
  }

  surface *= 1.12;

  float edgeZone = smoothstep(-6.75, -0.35, d);
  float topRim = clamp(dot(grad2D, normalize(vec2(-0.22, -0.97))), 0.0, 1.0);
  float botRim = pow(clamp(dot(grad2D, vec2(0.0, 1.0)), 0.0, 1.0), 1.35);

  if (isAccent) {
    surface = mix(surface, vec3(0.42, 0.71, 1.0), clamp(edgeZone * topRim * (0.55 - press * 0.20) * 1.35, 0.0, 1.0));
    surface = mix(surface, vec3(0.05, 0.24, 0.64), clamp(edgeZone * botRim * 0.42 * 1.4, 0.0, 1.0));
  } else {
    surface = mix(surface, vec3(1.0), clamp(edgeZone * topRim * (0.78 - press * 0.28) * 1.82, 0.0, 1.0));
    vec3 rimShade = (tier == 1) ? vec3(0.78, 0.82, 0.885) : vec3(0.75, 0.795, 0.865);
    surface = mix(surface, rimShade, clamp(edgeZone * botRim * 0.52 * 1.45, 0.0, 1.0));
  }

  if (press > 0.001) {
    vec3 pressTint = isAccent ? vec3(0.06, 0.30, 0.74) : vec3(0.88, 0.905, 0.945);
    surface = mix(surface, pressTint, press * 0.32);
  }

  return mix(bgCol, clamp(surface, 0.0, 1.0), mask);
}

void main() {
  vec2 px = FlutterFragCoord().xy;
  vec3 col = sampleScene(px);
  vec3 envBounce = mix(vec3(0.93, 0.945, 0.965), uEnvColor, imgFade);

  // --- HEADER ---
  if (px.y < headerCenter.y + headerHalf.y + 34.0) {
    vec2 pHead = px - headerCenter;
    if (abs(pHead.x) < headerHalf.x + 36.0) {
      float dHead = sdRoundBox(pHead, headerHalf, headerHalf.y);
      float dHeadPen = sdRoundBox(pHead - vec2(0.0, 5.5), headerHalf, headerHalf.y);
      float dHeadCrev = sdRoundBox(pHead - vec2(0.0, 1.5), headerHalf, headerHalf.y);
      col = render3DMatteSurface(col, envBounce, pHead, dHead, dHeadPen, dHeadCrev, 0.0, 0.0, true, false, 1);
    }

    vec2 pAct = px - actionCenter;
    if (abs(pAct.x) < actionHalf.x + 36.0) {
      float dAct = sdRoundBox(pAct, actionHalf, actionHalf.y);
      float dActPen = sdRoundBox(pAct - vec2(0.0, 5.5), actionHalf, actionHalf.y);
      float dActCrev = sdRoundBox(pAct - vec2(0.0, 1.5), actionHalf, actionHalf.y);
      col = render3DMatteSurface(col, envBounce, pAct, dAct, dActPen, dActCrev, 0.0, 0.0, true, false, 1);
    }

    vec2 pVid = px - videoCenter;
    if (abs(pVid.x) < headerBtnR + 28.0 && abs(pVid.y) < headerBtnR + 28.0) {
      vec2 pVidPhys = pVid - vec2(0.0, videoPress * 1.5);
      float rVid = headerBtnR * (1.0 - videoPress * 0.045);
      float dVid = length(pVidPhys) - rVid;
      float dVidPen = length(pVid - vec2(0.0, 3.2) * (1.0 - videoPress * 0.6)) - rVid;
      float dVidCrev = length(pVid - vec2(0.0, 1.0) * (1.0 - videoPress * 0.6)) - rVid;
      col = render3DMatteSurface(col, envBounce, pVidPhys, dVid, dVidPen, dVidCrev, videoPress, 0.0, false, false, 1);
    }

    vec2 pCal = px - callCenter;
    if (abs(pCal.x) < headerBtnR + 28.0 && abs(pCal.y) < headerBtnR + 28.0) {
      vec2 pCalPhys = pCal - vec2(0.0, callPress * 1.5);
      float rCal = headerBtnR * (1.0 - callPress * 0.045);
      float dCal = length(pCalPhys) - rCal;
      float dCalPen = length(pCal - vec2(0.0, 3.2) * (1.0 - callPress * 0.6)) - rCal;
      float dCalCrev = length(pCal - vec2(0.0, 1.0) * (1.0 - callPress * 0.6)) - rCal;
      col = render3DMatteSurface(col, envBounce, pCalPhys, dCal, dCalPen, dCalCrev, callPress, 0.0, false, false, 1);
    }

    fragColor = vec4(col, 1.0);
    return;
  }

  float barTopBound = capCenter.y - capHalf.y - 46.0;
  if (px.y < barTopBound) {
    fragColor = vec4(col, 1.0);
    return;
  }

  // --- BOTTOM CAPSULE ---
  vec2 pCap = px - capCenter;
  float capDrop = capPress * 1.4;
  vec2 pCapPhys = pCap - vec2(0.0, capDrop);

  if (abs(pCap.x) < capHalf.x + 48.0) {
    vec2 bCap = capHalf * (1.0 - capPress * 0.008);
    float rCap = capRadius * (1.0 - capPress * 0.008);
    float dCap = sdRoundBox(pCapPhys, bCap, rCap);
    float dCapPen = sdRoundBox(pCap - vec2(0.0, 7.0) * (1.0 - capPress * 0.5), bCap, rCap);
    float dCapCrev = sdRoundBox(pCap - vec2(0.0, 1.8) * (1.0 - capPress * 0.5), bCap, rCap);
    col = render3DMatteSurface(col, envBounce, pCapPhys, dCap, dCapPen, dCapCrev, capPress, isFocused, true, false, 0);
  }

  // --- PLUS BUTTON ---
  vec2 pPlus = px - (plusCenter + vec2(0.0, capDrop));
  if (abs(pPlus.x) < plusRadius + 28.0 && abs(pPlus.y) < plusRadius + 28.0) {
    float pressDrop = plusPress * 1.5;
    vec2 pPlusPhys = pPlus - vec2(0.0, pressDrop);
    float rPlus = plusRadius * (1.0 - plusPress * 0.045 + plusPulse * 0.06);
    float dPlus = length(pPlusPhys) - rPlus;
    float dPlusPen = length(pPlus - vec2(0.0, 3.2) * (1.0 - plusPress * 0.6)) - rPlus;
    float dPlusCrev = length(pPlus - vec2(0.0, 1.0) * (1.0 - plusPress * 0.6)) - rPlus;
    col = render3DMatteSurface(col, envBounce, pPlusPhys, dPlus, dPlusPen, dPlusCrev, plusPress, plusPulse, false, false, 1);

    if (dPlus < 1.0) {
      float angle = plusPulse * 1.5707963;
      float ca = cos(angle), sa = sin(angle);
      vec2 pRot = vec2(pPlusPhys.x * ca - pPlusPhys.y * sa, pPlusPhys.x * sa + pPlusPhys.y * ca);
      float plusAlpha = samplePlusIcon(pRot, 1.0 - plusPress * 0.045);
      if (plusAlpha > 0.001) col = mix(col, vec3(0.08, 0.10, 0.15), plusAlpha * 0.96);
    }
  }

  // --- SEND BUTTON ---
  vec2 pBtn = px - (btnCenter + vec2(0.0, capDrop));
  if (abs(pBtn.x) < btnRadius + 28.0 && abs(pBtn.y) < btnRadius + 28.0) {
    float pressDrop = btnPress * 1.5;
    vec2 pBtnPhys = pBtn - vec2(0.0, pressDrop);
    float rBtn = btnRadius * (1.0 - btnPress * 0.045 + sendPulse * 0.06);
    float dBtn = length(pBtnPhys) - rBtn;
    float dBtnPen = length(pBtn - vec2(0.0, 3.2) * (1.0 - btnPress * 0.6)) - rBtn;
    float dBtnCrev = length(pBtn - vec2(0.0, 1.0) * (1.0 - btnPress * 0.6)) - rBtn;
    col = render3DMatteSurface(col, envBounce, pBtnPhys, dBtn, dBtnPen, dBtnCrev, btnPress, sendPulse, false, true, 1);

    if (dBtn < 1.0) {
      vec2 pArrow = pBtnPhys + vec2(0.0, sendPulse * 2.5);
      float arrowAlpha = sampleArrowUpIcon(pArrow, 1.0 - btnPress * 0.045);
      if (arrowAlpha > 0.001) col = mix(col, vec3(1.0), arrowAlpha * 0.98);
    }
  }

  fragColor = vec4(col, 1.0);
}
