<template>
  <Modal v-model="isVisible" class="border-none">
    <SearchInput
      large
      placeholder="Поиск по названию, контенту или #тегам..."
      @search="toggleHandler"
      @keydown.esc="toggleHandler"
    />
  </Modal>
</template>

<script setup>
import Modal from "../components/Modal.vue";
import SearchInput from "./SearchInput.vue";

const isVisible = defineModel({ type: Boolean });

function toggleHandler() {
  isVisible.value = !isVisible.value;
}
</script>
