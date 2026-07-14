<script setup>
defineProps({ product: { type: Object, required: true }, name: { type: String, required: true }, compact: Boolean })
</script>

<template>
  <div class="productVisual" :class="[product.category_key, { compact }]">
    <div class="visualGlow"></div>
    <div class="hardware" aria-hidden="true">
      <template v-if="product.category_key === 'cpu'"><div class="cpuChip"><span v-for="n in 16" :key="n"></span></div></template>
      <template v-else-if="product.category_key === 'gpu'"><div class="gpuBody"><i></i><i></i><b></b></div></template>
      <template v-else-if="product.category_key === 'ram'"><div class="ramStick"><i v-for="n in 8" :key="n"></i></div></template>
      <template v-else-if="product.category_key === 'storage'"><div class="ssd"><i v-for="n in 4" :key="n"></i><b>M.2</b></div></template>
      <template v-else-if="product.category_key === 'motherboard'"><div class="board"><i></i><b></b><span v-for="n in 4" :key="n"></span></div></template>
      <template v-else><div class="psu"><i></i><b v-for="n in 8" :key="n"></b></div></template>
    </div>
    <div class="visualText"><small>{{ product.manufacturer }}</small><strong>{{ name }}</strong><span>{{ product.specs?.socket || product.specs?.capacity || product.specs?.power || product.specs?.memory || product.category_key.toUpperCase() }}</span></div>
    <slot />
  </div>
</template>
