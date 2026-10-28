import { router } from 'expo-router';
import { StyleSheet, Text, View, ScrollView, Pressable } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function HomeScreen() {
  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.brand}>learn it.</Text>

        <Text style={styles.greeting}>Welcome back 👋</Text>
        <Text style={styles.subtitle}>
          What would you like to learn today?
        </Text>

        <View style={styles.card}>
          <Text style={styles.cardLabel}>YOUR LEARNING</Text>
          <Text style={styles.cardTitle}>Ready to get started?</Text>
          <Text style={styles.cardDescription}>
            Your courses, quizzes, and progress will appear here.
          </Text>
        </View>
        <Pressable
  style={styles.createButton}
  onPress={() => {
    console.log('Create study set button pressed');
    router.push('/create-set');
  }}
>
  <Text style={styles.createButtonText}>+ Create study set</Text>
</Pressable>
        <Text style={styles.sectionTitle}>Quick actions</Text>

        <Pressable style={styles.action}>
          <Text style={styles.actionTitle}>📚 My courses</Text>
          <Text style={styles.actionDescription}>
            Continue where you left off
          </Text>
        </Pressable>

        <Pressable style={styles.action}>
          <Text style={styles.actionTitle}>🧠 Practice quizzes</Text>
          <Text style={styles.actionDescription}>
            Test your knowledge
          </Text>
        </Pressable>

        <Pressable style={styles.action}>
          <Text style={styles.actionTitle}>📈 My progress</Text>
          <Text style={styles.actionDescription}>
            Track your learning journey
          </Text>
        </Pressable>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({

  createButton: {
    backgroundColor: '#A3E635',
    padding: 18,
    borderRadius: 14,
    alignItems: 'center',
    marginBottom: 12,
  },
  createButtonText: {
    color: '#151719',
    fontSize: 16,
    fontWeight: '700',
  },
  container: {
    flex: 1,
    backgroundColor: '#0B0B0F',
  },
  content: {
    padding: 24,
    paddingBottom: 48,
    gap: 16,
  },
  brand: {
    fontSize: 28,
    fontWeight: '800',
    color: '#B6FF5C',
    marginBottom: 28,
  },
  greeting: {
    fontSize: 30,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  subtitle: {
    fontSize: 16,
    color: '#A1A1AA',
    marginBottom: 16,
  },
  card: {
    backgroundColor: '#1B1B23',
    padding: 24,
    borderRadius: 20,
    gap: 12,
    marginBottom: 16,
  },
  cardLabel: {
    fontSize: 12,
    fontWeight: '700',
    color: '#B6FF5C',
    letterSpacing: 1.5,
  },
  cardTitle: {
    fontSize: 23,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  cardDescription: {
    fontSize: 15,
    color: '#A1A1AA',
    lineHeight: 22,
  },
  sectionTitle: {
    fontSize: 21,
    fontWeight: '700',
    color: '#FFFFFF',
    marginTop: 8,
  },
  action: {
    backgroundColor: '#18181F',
    padding: 20,
    borderRadius: 16,
    gap: 6,
  },
  actionTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  actionDescription: {
    fontSize: 14,
    color: '#A1A1AA',
  },
});
