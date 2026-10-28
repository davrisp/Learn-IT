
import { useState } from 'react';
import {
  Alert,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function CreateSetScreen() {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');

  function handleCreate() {
    if (!title.trim()) {
      Alert.alert('Missing title', 'Please enter a title for your study set.');
      return;
    }

    Alert.alert(
      'Study set ready',
      'Your study set details are valid. Saving will be added next.'
    );
  }

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <ScrollView
          contentContainerStyle={styles.content}
          keyboardShouldPersistTaps="handled"
        >
          <Text style={styles.heading}>Create study set</Text>
          <Text style={styles.subtitle}>
            Organize what you want to learn.
          </Text>

          <View style={styles.field}>
            <Text style={styles.label}>Title</Text>
            <TextInput
              style={styles.input}
              placeholder="e.g. Financial Accounting"
              placeholderTextColor="#71717A"
              value={title}
              onChangeText={setTitle}
              maxLength={100}
            />
          </View>

          <View style={styles.field}>
            <Text style={styles.label}>Description</Text>
            <TextInput
              style={[styles.input, styles.multiline]}
              placeholder="What's this study set about?"
              placeholderTextColor="#71717A"
              value={description}
              onChangeText={setDescription}
              multiline
            />
          </View>

          <Pressable style={styles.button} onPress={handleCreate}>
            <Text style={styles.buttonText}>Create study set</Text>
          </Pressable>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  container: { flex: 1, backgroundColor: '#151719' },
  content: { padding: 24, gap: 24 },
  heading: { fontSize: 30, fontWeight: '700', color: '#FFFFFF' },
  subtitle: { fontSize: 16, color: '#A1A1AA' },
  field: { gap: 10 },
  label: { fontSize: 15, fontWeight: '600', color: '#FFFFFF' },
  input: {
    backgroundColor: '#25282B',
    borderWidth: 1,
    borderColor: '#3F3F46',
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    color: '#FFFFFF',
  },
  multiline: { minHeight: 110, textAlignVertical: 'top' },
  button: {
    backgroundColor: '#A3E635',
    borderRadius: 12,
    padding: 18,
    alignItems: 'center',
  },
  buttonText: {
    color: '#151719',
    fontSize: 16,
    fontWeight: '700',
  },
});
